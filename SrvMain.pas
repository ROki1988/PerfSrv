unit SrvMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs, System.SyncObjs,
  System.Generics.Collections, System.DateUtils, System.StrUtils,
  System.IOUtils,
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
    function MetricToStr4Graphite(Metric: TCollectedMetric; FmtType: TPdhFmtType): string;

  public
    function GetServiceController: TServiceController; override;
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
    (Metric as TMetricsCollectorThread).RefilList<string>(StrList, MetricToStr4Graphite);
  finally
    FStrList.UnlockList();
  end;
end;

function TPerfService.MetricToStr4Graphite(Metric: TCollectedMetric; FmtType: TPdhFmtType): string;
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
  FCollectThread := nil;
  FStrList := nil;
end;

procedure TPerfService.ServiceExecute(Sender: TService);
var
  StrList: TList<string>;
begin
  while not Terminated do
  begin

    StrList := FStrList.LockList();
    try
      TFile.AppendAllText(FLogFileName, Format('strCount = %d', [StrList.Count]) + sLineBreak, TEncoding.UTF8);
      if StrList.Count > 0 then
      begin
        TFile.AppendAllText(FLogFileName, string.Join(sLineBreak, StrList.ToArray), TEncoding.UTF8);
        StrList.Clear();
      end;
    finally
      FStrList.UnlockList();
    end;
    Sleep(5000);
  end;
end;

procedure TPerfService.ServicePause(Sender: TService; var Paused: Boolean);
begin
  FCollectThread.Suspend();

  Paused := True;
end;

procedure TPerfService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  FLogFileName := ExtractFilePath(ParamStr(0)) + FormatDateTime('yymmdd_', Now()) + 'perf.log';
  TFile.AppendAllText(FLogFileName, 'START' + sLineBreak, TEncoding.UTF8);
  FStrList := TThreadList<string>.Create();
  FCollectThread := TMetricsCollectorThread.Create(1000, ConvertToStrFrom);
  FCollectThread.AddCounter('\Process(firefox)\% Processor Time', 'Cpu(firefox)');
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

end.
