unit SrvMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs, System.SyncObjs,
  System.Generics.Collections, System.DateUtils, System.StrUtils,
  System.IOUtils, config, Winapi.ActiveX,
  CollectMetric, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient;

type
  TLoopState = (lsNone, lsContinue, lsExit);

type
  TPerfService = class(TService)
    IdUDPClient1: TIdUDPClient;
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceExecute(Sender: TService);
  private
    { Private êÈåæ }
    FCollectThread: TMetricsCollectorThread;
    FStrList: TThreadList<string>;

    FLogFileName: string;
    FLoopFunc: function: TLoopState of object;
    FLoopCount: Integer;

    FIsConsoleMode: Boolean;
    FSendIntervalMSec: Integer;

    procedure ChangeProcByStatus(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: string);

    function Func4Connected(): TLoopState;
    function Func4DisConnected(): TLoopState;

    procedure StartConsoleMode();
    procedure OutputToConsole(Metric: TObject);
    procedure SendMetric();
    procedure ConvertToStrFrom(Metric: TObject);
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

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  PerfService.Controller(CtrlCode);
end;

procedure TPerfService.ChangeProcByStatus(ASender: TObject;
  const AStatus: TIdStatus; const AStatusText: string);
begin
  case AStatus of
    hsResolving:
      ;
    hsConnecting:
      ;
    hsConnected:
      FLoopFunc := Func4Connected;
    hsDisconnecting:
      FLoopFunc := nil;
    hsDisconnected:
      FLoopFunc := Func4DisConnected;
    hsStatusText:
      ;
    ftpTransfer:
      ;
    ftpReady:
      ;
    ftpAborted:
      ;
  end;
end;

procedure TPerfService.ConvertToStrFrom(Metric: TObject);
var
  StrList: TList<string>;
begin
  if not(Assigned(Metric) and (Metric is TMetricsCollectorThread)) then
  begin
    Exit();
  end;

  StrList := FStrList.LockList();
  try
    (Metric as TMetricsCollectorThread).RefilList<string>(StrList,
      MetricToStr4Graphite);
  finally
    FStrList.UnlockList();
  end;
end;

function TPerfService.Func4Connected: TLoopState;
begin
  Result := lsNone;

  if FLoopCount * INTERVAL < FSendIntervalMSec then
  begin
    Inc(FLoopCount);
  end
  else
  begin
    SendMetric();
    FLoopCount := 0;
  end;
end;

function TPerfService.Func4DisConnected: TLoopState;
begin
  IdUDPClient1.Connect;
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
  StrList: TList<string>;
  CurrentStr: string;
begin
  if not(Assigned(Metric) and (Metric is TMetricsCollectorThread)) then
  begin
    Exit();
  end;

  StrList := FStrList.LockList();
  try
    (Metric as TMetricsCollectorThread).RefilList<string>(StrList,
      MetricToStr4Graphite);

    for CurrentStr in StrList do
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          Writeln(Output, CurrentStr);
        end);
    end;
  finally
    FStrList.UnlockList();
  end;
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

function TPerfService.GetSendPathFrom(const AddCounter: IXMLAddType): string;
var
  Instance: string;
  Counter: string;
begin
  Result := AddCounter.Path;
  Instance := EmptyStr;
  if not SameStr(AddCounter.Instance, EmptyStr) then
  begin
    Instance := Format('%s', [AddCounter.Instance]);
  end;

  Result := ReplaceStr(Result, '%COUNTER_INSTANCE%', Instance);
end;

function TPerfService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TPerfService.SendMetric;
var
  StrList: TList<string>;
  CurrentStr: string;
begin
  StrList := FStrList.LockList();
  try
    for CurrentStr in StrList do
    begin
      IdUDPClient1.Send(CurrentStr);
    end;
    StrList.Clear();
  finally
    FStrList.UnlockList();
  end;
end;

procedure TPerfService.ServiceContinue(Sender: TService;
var Continued: Boolean);
begin
  FCollectThread.Resume();
end;

procedure TPerfService.ServiceCreate(Sender: TObject);
begin
  SetCurrentDir(ExtractFileDir(ParamStr(0)));
  FLogFileName := TPath.Combine(GetCurrentDir, FormatDateTime('yymmdd_', Now())
    + 'perf.log');
  FCollectThread := nil;
  FStrList := nil;

  FIsConsoleMode := SameStr(ParamStr(1), '--console');
  FStrList := TThreadList<string>.Create();
  FCollectThread := TMetricsCollectorThread.Create();
  SetCollectSettingFrom(TPath.Combine(GetCurrentDir, 'config.xml'));

  if FIsConsoleMode then
  begin
    StartConsoleMode();
  end;
end;

procedure TPerfService.ServiceExecute(Sender: TService);
var
  LoopState: TLoopState;
begin
  FLoopCount := 0;
  while not Terminated do
  begin
    LoopState := lsNone;

    if Assigned(FLoopFunc) then
    begin
      LoopState := FLoopFunc();
    end;

    case LoopState of
      lsNone:
        ;
      lsContinue:
        Continue;
      lsExit:
        Exit;
    end;

    Sleep(INTERVAL);
    ServiceThread.ProcessRequests(False);
  end;
end;

procedure TPerfService.ServicePause(Sender: TService; var Paused: Boolean);
begin
  FCollectThread.Suspend();

  Paused := True;
end;

procedure TPerfService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  TFile.AppendAllText(FLogFileName, 'START' + sLineBreak, TEncoding.UTF8);

  IdUDPClient1.OnStatus := ChangeProcByStatus;
  IdUDPClient1.Connect();

  FCollectThread.Start();
  Started := True;
end;

procedure TPerfService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  FCollectThread.Terminate();
  FreeAndNil(FCollectThread);

  FreeAndNil(FStrList);
  TFile.AppendAllText(FLogFileName, 'STOP' + sLineBreak, TEncoding.UTF8);

  Stopped := True;
end;

procedure TPerfService.SetCollectSettingFrom(const ConfigFilePath: string);
var
  ConfigXML: IXMLConfigurationType;
begin
  if not(Assigned(FCollectThread) and (Assigned(IdUDPClient1))) then
  begin
    Exit();
  end;

  ConfigXML := nil;
  try
    CoInitialize(nil);
    try
      ConfigXML := Loadconfiguration(ConfigFilePath);
      SettingToUdpClientFrom(ConfigXML.Carbonator);
      SettingToCollectThreadFrom(ConfigXML.Carbonator);
    finally
      CoUninitialize
    end;
  except
    on E: Exception do
    begin
      TFile.AppendAllText(FLogFileName, 'Error' + E.Message + sLineBreak,
        TEncoding.UTF8);
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
  for ii := 0 to Carbonator.Counters.Count - 1 do
  begin
    AddCounter := Carbonator.Counters[ii];
    FCollectThread.AddCounter(GetCollectMetricFrom(AddCounter),
      GetSendPathFrom(AddCounter));
  end;
  TFile.AppendAllText(FLogFileName, 'CollectionInterval: ' +
    IntToStr(Carbonator.CollectionInterval) + sLineBreak, TEncoding.UTF8);

  if FIsConsoleMode then
  begin
    FCollectThread.SetIntervalEvent(Carbonator.CollectionInterval,
      OutputToConsole);
  end
  else
  begin
    FCollectThread.SetIntervalEvent(Carbonator.CollectionInterval,
      ConvertToStrFrom);
  end;
end;

procedure TPerfService.SettingToUdpClientFrom(const Carbonator
  : IXMLCarbonatorType);
begin
  IdUDPClient1.Host := Carbonator.Graphite.Server;
  IdUDPClient1.Port := Carbonator.Graphite.Port;
  FSendIntervalMSec := Carbonator.ReportingInterval;
  TFile.AppendAllText(FLogFileName, 'SendIntervalMSec: ' +
    IntToStr(FSendIntervalMSec) + sLineBreak, TEncoding.UTF8);
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

end.
