unit CollectMetric;

interface

uses
  Winapi.Windows, System.SysUtils, System.Generics.Collections, System.Threading,
  System.Classes, JwaPdh, JwaPdhMsg;

type
  TPdhFmtType = (pftRaw, pftAnsi, pftUnicode, pftLong, pftDouble, pftLarge,
    pftNoscale, pft1000, pftNodata, pftNocap100);

type
  TCollectedMetric = class
  private
    FCollectedDateTime: TDateTime;
    FMetric: TPdhFmtCounterValue;
    FSendPath: string;
  public
    constructor Create(const ASendPath: string;
      const AMetric: TPdhFmtCounterValue);
    property CollectedDateTime: TDateTime read FCollectedDateTime;
    property SendPath: string read FSendPath;
    property Metric: TPdhFmtCounterValue read FMetric;
  end;

type
  TMetricsCollectorThread = class(TThread)
  private
    FIntervalMilSec: Integer;
    hQuery: PDH_HQUERY;
    hCounters: TList<PDH_HCOUNTER>;
    FCounterPathPairs: TList<TPair<string, string>>;
    FCollectedMetricList: TThreadList<TCollectedMetric>;
    FIntervalEvent: TNotifyEvent;

    procedure InitQuery();
  protected
    procedure Execute(); override;
  public
    constructor Create(AIntervalMilSec: Integer = 1000;
      AIntervalEvent: TNotifyEvent = nil);
    destructor Destroy; override;

    procedure AddCounter(const CounterPath: string; const SendPath: string);

    procedure RefilList<TTarget>(const ExportList: TList<TTarget>; AConvertFunc: TFunc<TCollectedMetric, TPdhFmtType, TTarget>);
    procedure FreeListContent();
    property CollectedMetricList: TThreadList<TCollectedMetric>
      read FCollectedMetricList;
  end;

implementation

{ TCollectedMetric }

constructor TCollectedMetric.Create(const ASendPath: string;
  const AMetric: TPdhFmtCounterValue);
begin
  FCollectedDateTime := Now();
  FSendPath := ASendPath;
  FMetric := AMetric;
end;

{ TMetricsCollectorThread }

procedure TMetricsCollectorThread.AddCounter(const CounterPath,
  SendPath: string);
begin
  FCounterPathPairs.Add(TPair<string, string>.Create(CounterPath, SendPath));
end;

constructor TMetricsCollectorThread.Create(AIntervalMilSec: Integer = 1000;
  AIntervalEvent: TNotifyEvent = nil);
begin
  inherited Create(True);
  hQuery := 0;
  FIntervalMilSec := AIntervalMilSec;
  FreeOnTerminate := False;

  hCounters := nil;
  FCounterPathPairs := nil;
  FCollectedMetricList := nil;
  FIntervalEvent := AIntervalEvent;

  hCounters := TList<PDH_HCOUNTER>.Create();
  FCounterPathPairs := TList < TPair < string, string >>.Create();
  FCollectedMetricList := TThreadList<TCollectedMetric>.Create();
end;

destructor TMetricsCollectorThread.Destroy;
begin
  if hQuery <> 0 then
  begin
    PdhCloseQuery(hQuery);
  end;

  FreeListContent();

  FreeAndNil(FCollectedMetricList);
  FreeAndNil(hCounters);
  FreeAndNil(FCounterPathPairs);
  inherited;
end;

procedure TMetricsCollectorThread.Execute;
var
  CurrentValue: TPdhFmtCounterValue;
  ii: Integer;
  IntervalTask: ITask;
begin

  InitQuery();

  while not Terminated do
  begin

    PdhCollectQueryData(hQuery);

    for ii := 0 to hCounters.Count - 1 do
    begin
      ZeroMemory(@CurrentValue, SizeOf(TPdhFmtCounterValue));
      PdhGetFormattedCounterValue(hCounters[ii], PDH_FMT_LONG, nil,
        CurrentValue);
      FCollectedMetricList.Add(TCollectedMetric.Create(FCounterPathPairs[ii]
        .Value, CurrentValue));
    end;

    IntervalTask := nil;
    if Assigned(FIntervalEvent) then
    begin
      IntervalTask := TTask.Create(
        procedure
        begin
          FIntervalEvent(Self);
        end
      );
      IntervalTask.Start();
    end;

    Sleep(FIntervalMilSec);

    if Assigned(IntervalTask) then
    begin
      TTask.WaitForAll([IntervalTask]);
    end;
  end;
end;

procedure TMetricsCollectorThread.FreeListContent;
begin
  RefilList<TObject>(nil, nil);
end;

procedure TMetricsCollectorThread.InitQuery;
var
  CurrentHCounter: PDH_HCOUNTER;
  ii: Integer;
begin
  PdhOpenQuery(nil, 0, hQuery);

  for ii := 0 to FCounterPathPairs.Count - 1 do
  begin
    CurrentHCounter := 0;
    if not Succeeded(PdhAddCounter(hQuery, PChar(FCounterPathPairs[ii].Key), 0,
      CurrentHCounter)) then
    begin
      Exit();
    end;

    if CurrentHCounter <> 0 then
    begin
      hCounters.Add(CurrentHCounter);
    end;
  end;

  PdhCollectQueryData(hQuery);
  Sleep(FIntervalMilSec);
end;

procedure TMetricsCollectorThread.RefilList<TTarget>(const ExportList: TList<TTarget>; AConvertFunc: TFunc<TCollectedMetric, TPdhFmtType, TTarget>);
var
  ii: Integer;
  Metrics: TList<TCollectedMetric>;
begin
  Metrics := FCollectedMetricList.LockList();
  try
    for ii := 0 to Metrics.Count - 1 do
    begin

      if Assigned(ExportList) and Assigned(AConvertFunc) then
      begin
        ExportList.Add(AConvertFunc(Metrics[ii], pftLong))
      end;

      Metrics[ii].Free;
      Metrics[ii] := nil;
    end;
    Metrics.Clear();
  finally
    FCollectedMetricList.UnlockList();
  end;
end;

end.
