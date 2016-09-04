unit CollectMetric;

interface

uses
  Winapi.Windows, System.SysUtils, System.Generics.Collections,
  System.Threading,
  System.Classes, JwaPdh, JwaPdhMsg;

type
  TPdhFmtType = (pftRaw, pftAnsi, pftUnicode, pftLong, pftDouble, pftLarge,
    pftNoscale, pft1000, pftNodata, pftNocap100);

type
  TCollectedMetric = class
  strict private
    FCollectedDateTime: TDateTime;
    FMetric: TPdhFmtCounterValue;
    FSendPath: string;
  private
      constructor Create(const ASendPath: string;
      const AMetric: TPdhFmtCounterValue);
  public
    /// <remarks>
    ///   取得日時
    /// </remarks>
    property CollectedDateTime: TDateTime read FCollectedDateTime;

    /// <remarks>
    ///   送信用パス
    ///  ここに内容が良いけど･･･
    /// </remarks>
    property SendPath: string read FSendPath;

    /// <remarks>
    ///   取得したメトリクス
    /// </remarks>
    property Metric: TPdhFmtCounterValue read FMetric;
  end;

type
  TMetricsCollectorThread = class(TThread)
  strict private
    FIntervalMilSec: Integer;
    hQuery: PDH_HQUERY;
    hCounters: TList<PDH_HCOUNTER>;
    FCollectedMetricList: TThreadList<TCollectedMetric>;
    FIntervalEvent: TNotifyEvent;

    procedure InitQuery();
    procedure FreeListContent();
  private
  protected
    FCounterPathPairs: TList<TPair<string, string>>;

    function GetCollectMetricFrom(const Category, Counter, Instance
      : string): string;

    procedure Execute(); override;
  public
    constructor Create();
    destructor Destroy; override;

    /// <remarks>
    ///   スレッド内の定期処理設定
    /// </remarks>
    /// <param name="AIntervalMilSec">
    ///   イベントの実行周期
    /// </param>
    /// <param name="AIntervalEvent">
    ///   イベント
    /// </param>
    procedure SetIntervalEvent(AIntervalMilSec: Integer;
      AIntervalEvent: TNotifyEvent);

    /// <remarks>
    ///   取得したいカウンターを追加する
    /// </remarks>
    /// <param name="Category">
    ///   カテゴリー ex)  Processor
    /// </param>
    /// <param name="Counter">
    ///   カウンター ex) % Processor Time
    /// </param>
    /// <param name="Instance">
    ///   インスタンス名 ex) _Total
    /// </param>
    /// <param name="SendPath">
    ///   送信パス
    /// </param>
    procedure AddCounter(const Category: string; const Counter: string; const Instance: string; const SendPath: string);

    /// <remarks>
    ///   取得したメトリクスの詰め替え関数
    /// </remarks>
    /// <param name="ExportList">
    ///   詰め替え先リスト
    /// </param>
    /// <param name="AConvertFunc">
    ///   変換仕様
    /// </param>
    procedure RefilList<TTarget>(const ExportList: TList<TTarget>;
      AConvertFunc: TFunc<TCollectedMetric, TPdhFmtType, TTarget>);
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

function TMetricsCollectorThread.GetCollectMetricFrom(const Category, Counter, Instance: string): string;
var
  FixInstance: string;
  FixCounter: string;
begin
  Result := EmptyStr;
  FixInstance := EmptyStr;
  FixCounter := EmptyStr;

  if not SameStr(Instance, EmptyStr) then
  begin
    FixInstance := Format('(%s)', [Instance]);
  end;

  if not SameStr(Counter, '*') then
  begin
    FixCounter := Format('%s', [Counter]);
  end;

  Result := Format('\%s%s\%s', [Category, FixInstance, FixCounter]);
end;

procedure TMetricsCollectorThread.AddCounter(const Category, Counter, Instance,
  SendPath: string);
begin
  FCounterPathPairs.Add(TPair<string, string>.Create(GetCollectMetricFrom(Category, Counter, Instance), SendPath));
end;

constructor TMetricsCollectorThread.Create();
begin
  inherited Create(True);
  hQuery := 0;
  FIntervalMilSec := 1000;
  FreeOnTerminate := False;

  hCounters := nil;
  FCounterPathPairs := nil;
  FCollectedMetricList := nil;
  FIntervalEvent := nil;

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
  TThread.NameThreadForDebugging(Self.ClassName);

  InitQuery();

  while not Terminated do
  begin

    PdhCollectQueryData(hQuery);

    for ii := 0 to hCounters.Count - 1 do
    begin
      ZeroMemory(@CurrentValue, SizeOf(TPdhFmtCounterValue));
      PdhGetFormattedCounterValue(hCounters[ii], PDH_FMT_DOUBLE, nil,
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
        end);
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

procedure TMetricsCollectorThread.RefilList<TTarget>(const ExportList
  : TList<TTarget>; AConvertFunc: TFunc<TCollectedMetric, TPdhFmtType,
  TTarget>);
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
        ExportList.Add(AConvertFunc(Metrics[ii], pftDouble))
      end;

      Metrics[ii].Free;
      Metrics[ii] := nil;
    end;
    Metrics.Clear();
  finally
    FCollectedMetricList.UnlockList();
  end;
end;

procedure TMetricsCollectorThread.SetIntervalEvent(AIntervalMilSec: Integer;
AIntervalEvent: TNotifyEvent);
begin
  FIntervalMilSec := AIntervalMilSec;
  FIntervalEvent := AIntervalEvent;
end;

end.
