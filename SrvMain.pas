unit SrvMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs, System.SyncObjs,
  System.Generics.Collections, System.DateUtils, System.StrUtils,
  System.IOUtils, config, Winapi.ActiveX,
  CollectMetric, TcpSendThread, Xml.xmldom, Xml.XMLIntf, Xml.Win.msxmldom,
  Xml.XMLDoc;

type
  TPerfService = class(TService)
    config: TXMLDocument;
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceExecute(Sender: TService);
  private
    { Private 宣言 }
    FCollectThread: TMetricsCollectorThread;
    FSendThread: TTcpSendThread;

    FLogStream: TStreamWriter;
    FComputerName: string;

    FIsConsoleMode: Boolean;

    procedure StartConsoleMode();

    function IsExistSubThreads(): Boolean;
    function StartedSubThreads(): Boolean;
    function StartSubThreads(): Boolean;
    function FreeSubThreads(): Boolean;
  protected

    procedure OutputToSender(Metric: TObject);

    function GetLocalMachineName(): string;

    /// <remarks>
    /// メトリクスから graphite フォーマットへの変換仕様
    /// </remarks>
    /// <param name="Metric">
    /// 取得されたメトリクス
    /// </param>
    /// <param name="FmtType">
    /// パラメータのタイプ
    /// </param>
    /// <returns>
    /// graphite フォーマットの文字列
    /// </returns>
    function MetricToStr4Graphite(Metric: TCollectedMetric;
      FmtType: TPdhFmtType): string;

    /// <remarks>
    /// 設定ファイルにそったサブスレッドを生成する
    /// </remarks>
    /// <param name="ConfigXML">
    /// 設定が書かれたxml
    /// </param>
    procedure InitSubThreadsFrom(const ConfigXML: TXMLDocument);

    /// <remarks>
    /// 通信スレッドの生成処理
    /// </remarks>
    /// <param name="Carbonator">
    /// 設定が書かれたxml
    /// </param>
    /// <returns>
    /// 通信スレッド
    /// </returns>
    function CreateUdpClientFrom(const Carbonator: IXMLCarbonatorType)
      : TTcpSendThread;

    /// <remarks>
    /// パフォーマンス取得スレッドの生成処理
    /// </remarks>
    /// <param name="Carbonator">
    /// 設定が書かれたxml
    /// </param>
    /// <returns>
    /// パフォーマンス取得スレッド
    /// </returns>
    function CreateCollectThreadFrom(const Carbonator: IXMLCarbonatorType)
      : TMetricsCollectorThread;
    function GetSendPathFrom(const AddCounter: IXMLAddType): string;
  public
    function GetServiceController: TServiceController; override;
    { Public 宣言 }
  end;

var
  PerfService: TPerfService;

implementation

uses
  ObjectUtils, IdGlobal;

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  PerfService.Controller(CtrlCode);
end;

procedure TPerfService.OutputToSender(Metric: TObject);
var
  Worker: TMetricsCollectorThread;
  StrList: TList<string>;
begin
  if not TObject.TryCastTo(Metric, Worker) then
  begin
    Exit();
  end;

  StrList := TList<string>.Create();
  try
    Worker.RefilList<string>(StrList, MetricToStr4Graphite);

    FSendThread.AddSendData(StrList);
    if FIsConsoleMode then
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          Write(Output, string.Join(EmptyStr, StrList.ToArray));
        end);
    end;
  finally
    FreeAndNil(StrList);
  end;
end;

function TPerfService.MetricToStr4Graphite(Metric: TCollectedMetric;
FmtType: TPdhFmtType): string;
var
  UnixTime: Int64;
  S: string;
begin
  Result := EmptyStr;
  UnixTime := 0;
  with Metric do
  begin
    UnixTime := DateTimeToUnix(CollectedDateTime, False);
    S := EmptyStr;
    case FmtType of
      pftRaw:
        ;
      pftAnsi:
        S := string(Metric.AnsiStringValue);
      pftUnicode:
        S := Metric.WideStringValue;
      pftLong:
        S := IntToStr(Metric.longValue);
      pftDouble:
        S := FloatToStr(Metric.doubleValue);
      pftLarge:
        S := IntToStr(Metric.largeValue);
      pftNoscale:
        ;
      pft1000:
        ;
      pftNodata:
        ;
      pftNocap100:
        ;
    end;
    Result := string.Join(' ', [SendPath, S, UnixTime.ToString]) + #10;
  end;
end;

function TPerfService.FreeSubThreads(): Boolean;
begin
  FCollectThread.Terminate();
  FSendThread.Terminate();

  FreeAndNil(FCollectThread);
  FreeAndNil(FSendThread);

  Result := not IsExistSubThreads();
end;

function TPerfService.GetLocalMachineName: string;
var
  Size: DWord;
begin
  Result := EmptyStr;

  Size := 0;
  GetComputerNameEx(ComputerNameNetBIOS, nil, Size);
  SetLength(Result, Size);

  if not GetComputerNameEx(ComputerNameNetBIOS, PWideChar(Result), Size) then
  begin
    RaiseLastOSError;
  end;
  SetLength(Result, Size);
end;

function TPerfService.GetSendPathFrom(const AddCounter: IXMLAddType): string;
var
  Instance: string;
begin
  Result := AddCounter.Path;
  Instance := EmptyStr;

  if not SameStr(AddCounter.Instance, EmptyStr) then
  begin
    Instance := Format('%s', [AddCounter.Instance]);
  end;

  Result := ReplaceStr(Result, '%HOST%', FComputerName);
  Result := ReplaceStr(Result, '%COUNTER_CATEGORY%', AddCounter.Category);
  Result := ReplaceStr(Result, '%COUNTER_INSTANCE%', Instance);
end;

function TPerfService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

function TPerfService.IsExistSubThreads: Boolean;
begin
  Result := Assigned(FCollectThread) and Assigned(FSendThread);
end;

procedure TPerfService.ServiceContinue(Sender: TService;
var Continued: Boolean);
begin
  InitSubThreadsFrom(config);
  Continued := StartSubThreads();
end;

procedure TPerfService.ServiceCreate(Sender: TObject);
var
  LogFileName: string;
begin
  SetCurrentDir(ExtractFileDir(ParamStr(0)));
  LogFileName := TPath.Combine(GetCurrentDir, FormatDateTime('yymmdd_', Now()) +
    'perf.log');
  FComputerName := GetLocalMachineName();

  FCollectThread := nil;
  FSendThread := nil;
  FLogStream := nil;

  FLogStream := TStreamWriter.Create(LogFileName, True, TEncoding.UTF8);
  FIsConsoleMode := FindCmdLineSwitch('console');
  InitSubThreadsFrom(config);

  if FIsConsoleMode then
  begin
{$IFDEF DEBUG}
    ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
    StartConsoleMode();
  end;
end;

procedure TPerfService.ServiceExecute(Sender: TService);
const
  INTERVAL = 100;
begin
  FLogStream.WriteLine('ServiceExecute');
  while not Terminated do
  begin

    Sleep(INTERVAL);
    ServiceThread.ProcessRequests(False);
  end;
end;

procedure TPerfService.ServicePause(Sender: TService; var Paused: Boolean);
begin
  Paused := FreeSubThreads();
end;

procedure TPerfService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  Started := StartSubThreads();

  FLogStream.WriteLine('ServiceStart');
end;

procedure TPerfService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  Stopped := FreeSubThreads();

  FLogStream.WriteLine('ServiceStop');
  FLogStream.Flush();
  FreeAndNil(FLogStream);
end;

procedure TPerfService.InitSubThreadsFrom(const ConfigXML: TXMLDocument);
var
  config: IXMLConfigurationType;
begin
  if IsExistSubThreads() then
  begin
    Exit();
  end;

  config := nil;
  try
    config := Getconfiguration(ConfigXML);
    FCollectThread := CreateCollectThreadFrom(config.Carbonator);
    FSendThread := CreateUdpClientFrom(config.Carbonator);
  except
    on E: Exception do
    begin
      FLogStream.WriteLine('Error' + E.Message);
      raise E;
    end;
  end;
end;

function TPerfService.CreateCollectThreadFrom(const Carbonator
  : IXMLCarbonatorType): TMetricsCollectorThread;
var
  AddCounter: IXMLAddType;
  ii: Integer;
  Count: Integer;
begin
  Result := nil;
  Result := TMetricsCollectorThread.Create();

  Count := Carbonator.Counters.Count;
  for ii := 0 to Count - 1 do
  begin
    AddCounter := Carbonator.Counters[ii];
    Result.AddCounter(AddCounter.Category, AddCounter.Counter,
      AddCounter.Instance, GetSendPathFrom(AddCounter));
  end;
  Result.SetIntervalEvent(Carbonator.CollectionInterval, OutputToSender);

  FLogStream.WriteLine('CollectionInterval: ' +
    IntToStr(Carbonator.CollectionInterval));
end;

function TPerfService.CreateUdpClientFrom(const Carbonator: IXMLCarbonatorType)
  : TTcpSendThread;
begin
  Result := nil;
  Result := TTcpSendThread.Create(True, Carbonator.Graphite.Server,
    Carbonator.Graphite.Port, Carbonator.ReportingInterval,
    Carbonator.Counters.Count * 1000, encASCII);

  FLogStream.WriteLine('SendIntervalMSec: ' +
    IntToStr(Carbonator.ReportingInterval));
  FLogStream.WriteLine(Carbonator.Graphite.Server);
end;

procedure TPerfService.StartConsoleMode;
begin
  AllocConsole;
  try
    Writeln(Output, DateTimeToStr(Now()));
    StartSubThreads();

    FCollectThread.WaitFor();
  finally
    FreeConsole;
  end;
end;

function TPerfService.StartedSubThreads: Boolean;
begin
  Result := FCollectThread.Started and FSendThread.Started;
end;

function TPerfService.StartSubThreads: Boolean;
begin
  FLogStream.WriteLine('[begin] StartSubThreads');
  Result := False;
  if IsExistSubThreads then
  begin
    FLogStream.WriteLine('     ExistSubThreads');
    FSendThread.Start;
    FCollectThread.Start;
    Sleep(100);

    Result := StartedSubThreads();
  end;
  FLogStream.WriteLine('     Result: ' + BoolToStr(Result, True));
  FLogStream.WriteLine('[end] StartSubThreads');
end;

end.
