unit SrvMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs, System.SyncObjs,
  System.Generics.Collections, System.DateUtils, System.StrUtils,
  System.IOUtils, config, Winapi.ActiveX,
  CollectMetric, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient;

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
    { Private �錾 }
    FCollectThread: TMetricsCollectorThread;
    FStrList: TThreadList<string>;

    FLogFileName: string;

    procedure OutputToConsole(Metric: TObject);
    procedure SendMetric();
    procedure ConvertToStrFrom(Metric: TObject);
    function MetricToStr4Graphite(Metric: TCollectedMetric;
      FmtType: TPdhFmtType): string;
    procedure SettingToUdpClientFrom(const Carbonator: IXMLCarbonatorType);
    procedure SettingToCollectThreadFrom(const Carbonator: IXMLCarbonatorType);
    function GetCollectMetricFrom(const AddCounter: IXMLAddType): string;
    function GetSendPathFrom(const AddCounter: IXMLAddType): string;
  public
    function GetServiceController: TServiceController; override;
    procedure SetCollectSettingFrom(const ConfigFilePath: string);
    { Public �錾 }
  end;

var
  PerfService: TPerfService;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  PerfService.Controller(CtrlCode);
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
  FStrList := TThreadList<string>.Create();


  if SameStr(ParamStr(1), '--console') then
  begin
    AllocConsole;
    FCollectThread := TMetricsCollectorThread.Create(1000, OutputToConsole);
    SetCollectSettingFrom(TPath.Combine(GetCurrentDir, 'config.xml'));
    Writeln(Output, DateTimeToStr(Now()));
    FCollectThread.Start;
    FCollectThread.WaitFor;
  end
  else
  begin
    FCollectThread := TMetricsCollectorThread.Create(1000, ConvertToStrFrom);
    SetCollectSettingFrom(TPath.Combine(GetCurrentDir, 'config.xml'));
  end;
end;

procedure TPerfService.ServiceExecute(Sender: TService);
const
  INTERVAL = 100;
var
  LoopCount: Integer;
begin
  LoopCount := 0;
  while not Terminated do
  begin

    if LoopCount * INTERVAL < 5000 then
    begin
      Inc(LoopCount, INTERVAL);
    end
    else
    begin
      if not IdUDPClient1.Connected then
      begin
        IdUDPClient1.Connect;
      end;

      if IdUDPClient1.Connected then
      begin
        SendMetric();
      end;
      LoopCount := 0;
    end;

    ServiceThread.ProcessRequests(False);
    Sleep(INTERVAL);
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
end;

procedure TPerfService.SettingToUdpClientFrom(const Carbonator
  : IXMLCarbonatorType);
begin
  IdUDPClient1.Host := Carbonator.Graphite.Server;
  IdUDPClient1.Port := Carbonator.Graphite.Port;
end;

end.
