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
    { Private êÈåæ }
    FCollectThread: TMetricsCollectorThread;
    FStrList: TThreadList<string>;

    FLogFileName: string;

    procedure ConvertToStrFrom(Metric: TObject);
    function MetricToStr4Graphite(Metric: TCollectedMetric;
      FmtType: TPdhFmtType): string;
    procedure SettingToUdpClientFrom(const Carbonator: IXMLCarbonatorType);
    procedure SettingToCollectThreadFrom(const Carbonator: IXMLCarbonatorType);
    function GetCollectMetricFrom(const AddCounter: IXMLAddType): string;
  public
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

  if not SameStr(AddCounter.Instance, '*') then
  begin
    Instance := Format('%s', [AddCounter.Instance]);
  end;

  Result := Format('\%s%s\%s', [AddCounter.Category, Instance, Counter]);
end;

function TPerfService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TPerfService.ServiceContinue(Sender: TService;
  var Continued: Boolean);
begin
  FCollectThread.Resume();
end;

procedure TPerfService.ServiceCreate(Sender: TObject);
begin
  SetCurrentDir(ExtractFileDir(ParamStr(0)));
  FLogFileName := TPath.Combine(GetCurrentDir, FormatDateTime('yymmdd_', Now()) + 'perf.log');
  FCollectThread := nil;
  FStrList := nil;
end;

procedure TPerfService.ServiceExecute(Sender: TService);
const
  INTERVAL = 100;
var
  StrList: TList<string>;
  CurrentStr: string;
  LoopCount: Integer;
begin
  LoopCount := 0;
  while not Terminated do
  begin

    if LoopCount * INTERVAL < 5000 then
    begin
      Inc(LoopCount, INTERVAL);
      Continue;
    end;

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
  FStrList := TThreadList<string>.Create();
  FCollectThread := TMetricsCollectorThread.Create(1000, ConvertToStrFrom);

  try
    CoInitialize(nil);
    try
      SetCollectSettingFrom(TPath.Combine(GetCurrentDir, 'config.xml'));
    finally
      CoUninitialize
    end;
  except
    on E: Exception do
    begin
      TFile.AppendAllText(FLogFileName, 'Error' + E.Message + sLineBreak, TEncoding.UTF8);
      raise E;
    end;
  end;

  FCollectThread.Start();
  Started := True;
end;

procedure TPerfService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  FCollectThread.Terminate();
  Sleep(1000);
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
  ConfigXML := Loadconfiguration(ConfigFilePath);
  SettingToUdpClientFrom(ConfigXML.Carbonator);
  SettingToCollectThreadFrom(ConfigXML.Carbonator);
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
      AddCounter.Path);
  end;
end;

procedure TPerfService.SettingToUdpClientFrom(const Carbonator
  : IXMLCarbonatorType);
begin
  IdUDPClient1.Host := Carbonator.Graphite.Server;
  IdUDPClient1.Port := Carbonator.Graphite.Port;
end;

end.
