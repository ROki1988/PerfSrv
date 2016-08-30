unit SrvMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs, System.SyncObjs,
  System.Generics.Collections, System.DateUtils, System.StrUtils,
  System.IOUtils, config, Winapi.ActiveX,
  CollectMetric, TcpSendThread;

type
  TPerfService = class(TService)
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceExecute(Sender: TService);
  private
    { Private êÈåæ }
    FCollectThread: TMetricsCollectorThread;
    FSendThread: TTcpSendThread;

    FLogStream: TStreamWriter;
    FLogFileName: string;
    FComputerName: string;

    FIsConsoleMode: Boolean;

    function GetMaxStateCollectCount: Integer;

    procedure StartConsoleMode();

    function IsExistSubThreads(): Boolean;
    function StartedSubThreads(): Boolean;
    function StartSubThreads(): Boolean;
    function FreeSubThreads(): Boolean;
  protected
    FCollectCounter: Integer;

    procedure OutputToConsole(Metric: TObject);
    procedure OutputToSender(Metric: TObject);

    function GetLocalMachineName(): string;
    function MetricToStr4Graphite(Metric: TCollectedMetric;
      FmtType: TPdhFmtType): string;
    procedure SettingToUdpClientFrom(const Carbonator: IXMLCarbonatorType);
    procedure SettingToCollectThreadFrom(const Carbonator: IXMLCarbonatorType);
    function GetCollectMetricFrom(const AddCounter: IXMLAddType): string;
    function GetSendPathFrom(const AddCounter: IXMLAddType): string;
  public const
    INTERVAL = 100;
    function GetServiceController: TServiceController; override;
    procedure SetCollectSettingFrom(const ConfigFilePath: string);
    { Public êÈåæ }
  end;

var
  PerfService: TPerfService;

implementation

uses
  ObjectUtils;

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
  finally
    FreeAndNil(StrList);
  end;
end;

function TPerfService.MetricToStr4Graphite(Metric: TCollectedMetric;
  FmtType: TPdhFmtType): string;
var
  UnixTime: Int64;
begin
  Result := EmptyStr;
  UnixTime := 0;
  with Metric do
  begin
    UnixTime := DateTimeToUnix(CollectedDateTime, False);
    case FmtType of
      pftRaw:
        ;
      pftAnsi:
        Result := Format('%s %s %d', [SendPath, Metric.AnsiStringValue,
          UnixTime]);
      pftUnicode:
        Result := Format('%s %s %d', [SendPath, Metric.WideStringValue,
          UnixTime]);
      pftLong:
        Result := Format('%s %d %d', [SendPath, Metric.longValue, UnixTime]);
      pftDouble:
        Result := Format('%s %f %d', [SendPath, Metric.doubleValue, UnixTime]);
      pftLarge:
        Result := Format('%s %d %d', [SendPath, Metric.largeValue, UnixTime]);
      pftNoscale:
        ;
      pft1000:
        ;
      pftNodata:
        ;
      pftNocap100:
        ;
    end;
  end;
end;

procedure TPerfService.OutputToConsole(Metric: TObject);
var
  Worker: TMetricsCollectorThread;
  StrList: TList<string>;
  CurrentStr: string;
begin
  if not TObject.TryCastTo(Metric, Worker) then
  begin
    Exit();
  end;

  StrList := TList<string>.Create();
  try
    Worker.RefilList<string>(StrList, MetricToStr4Graphite);

    for CurrentStr in StrList do
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          Writeln(Output, CurrentStr);
        end);
    end;
  finally
    FreeAndNil(StrList);
  end;
end;

function TPerfService.FreeSubThreads(): Boolean;
begin
  FCollectThread.Terminate();
  FreeAndNil(FCollectThread);
  FSendThread.Terminate();
  FreeAndNil(FSendThread);

  Result := not IsExistSubThreads();
end;

function TPerfService.GetCollectMetricFrom(const AddCounter
  : IXMLAddType): string;
var
  Instance: string;
  Counter: string;
begin
  Result := EmptyStr;
  Instance := EmptyStr;
  Counter := EmptyStr;

  if not SameStr(AddCounter.Instance, EmptyStr) then
  begin
    Instance := Format('(%s)', [AddCounter.Instance]);
  end;

  if not SameStr(AddCounter.Counter, '*') then
  begin
    Counter := Format('%s', [AddCounter.Counter]);
  end;

  Result := Format('\%s%s\%s', [AddCounter.Category, Instance, Counter]);
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

function TPerfService.GetMaxStateCollectCount: Integer;
begin
  Result := 1000 * FCollectCounter;
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
  SetCollectSettingFrom(TPath.Combine(GetCurrentDir, 'config.xml'));
  Continued := StartSubThreads();
end;

procedure TPerfService.ServiceCreate(Sender: TObject);
begin
  FCollectCounter := 0;
  SetCurrentDir(ExtractFileDir(ParamStr(0)));
  FLogFileName := TPath.Combine(GetCurrentDir, FormatDateTime('yymmdd_', Now())
    + 'perf.log');
  FComputerName := GetLocalMachineName();

  FCollectThread := nil;
  FSendThread := nil;
  FLogStream := nil;

  FLogStream := TStreamWriter.Create(FLogFileName, True, TEncoding.UTF8);
  FIsConsoleMode := FindCmdLineSwitch('console');
  SetCollectSettingFrom(TPath.Combine(GetCurrentDir, 'config.xml'));

  if FIsConsoleMode then
  begin
    StartConsoleMode();
  end;
end;

procedure TPerfService.ServiceExecute(Sender: TService);
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

procedure TPerfService.SetCollectSettingFrom(const ConfigFilePath: string);
var
  ConfigXML: IXMLConfigurationType;
begin
  if IsExistSubThreads() then
  begin
    Exit();
  end;

  ConfigXML := nil;
  try
    CoInitialize(nil);
    try
      ConfigXML := Loadconfiguration(ConfigFilePath);
      SettingToCollectThreadFrom(ConfigXML.Carbonator);
      SettingToUdpClientFrom(ConfigXML.Carbonator);
    finally
      CoUninitialize
    end;
  except
    on E: Exception do
    begin
      FLogStream.WriteLine('Error' + E.Message);
      raise E;
    end;
  end;
end;

procedure TPerfService.SettingToCollectThreadFrom(const Carbonator
  : IXMLCarbonatorType);
var
  AddCounter: IXMLAddType;
  ii: Integer;
begin
  FCollectThread := TMetricsCollectorThread.Create();

  FCollectCounter := Carbonator.Counters.Count;
  for ii := 0 to FCollectCounter - 1 do
  begin
    AddCounter := Carbonator.Counters[ii];
    FCollectThread.AddCounter(GetCollectMetricFrom(AddCounter),
      GetSendPathFrom(AddCounter));
  end;
  FLogStream.WriteLine('CollectionInterval: ' +
    IntToStr(Carbonator.CollectionInterval));

  if FIsConsoleMode then
  begin
    FCollectThread.SetIntervalEvent(Carbonator.CollectionInterval,
      OutputToConsole);
  end
  else
  begin
    FCollectThread.SetIntervalEvent(Carbonator.CollectionInterval,
      OutputToSender);
  end;
end;

procedure TPerfService.SettingToUdpClientFrom(const Carbonator
  : IXMLCarbonatorType);
begin
  FSendThread := TTcpSendThread.Create(True, Carbonator.Graphite.Server,
    Carbonator.Graphite.Port, Carbonator.ReportingInterval,
    GetMaxStateCollectCount);

  FLogStream.WriteLine('SendIntervalMSec: ' +
    IntToStr(Carbonator.ReportingInterval));
  FLogStream.WriteLine(Carbonator.Graphite.Server);
end;

procedure TPerfService.StartConsoleMode;
begin
  AllocConsole;
  try
    Writeln(Output, DateTimeToStr(Now()));
    FCollectThread.Start;
    FCollectThread.WaitFor;

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
