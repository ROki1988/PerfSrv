﻿unit CollectMetric;

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
    FCounterHandle: PDH_HCOUNTER;
  private
    constructor Create(const ACounterHandle: PDH_HCOUNTER;
      const AMetric: TPdhFmtCounterValue);
  public
    /// <summary>
    /// 取得日時
    /// </summary>
    property CollectedDateTime: TDateTime read FCollectedDateTime;

    /// <summary>
    /// 送信用パス;
    /// ここにないほうが良いけど･･･
    /// </summary>
    property CounterHandle: PDH_HCOUNTER read FCounterHandle;

    /// <summary>
    /// 取得したメトリクス
    /// </summary>
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
    procedure DoIntervalEvent();
  protected
    function TryMakeCounterPathFrom(const Element: PPdhCounterPathElements;
      var Path: string): Boolean;

    procedure Execute(); override;
  public
    constructor Create();
    destructor Destroy; override;

    /// <summary>
    /// スレッド内の定期処理設定
    /// </summary>
    /// <param name="AIntervalMilSec">
    /// イベントの実行周期
    /// </param>
    /// <param name="AIntervalEvent">
    /// イベント
    /// </param>
    procedure SetIntervalEvent(AIntervalMilSec: Integer;
      AIntervalEvent: TNotifyEvent);

    /// <summary>
    /// 取得したいカウンターを追加する
    /// </summary>
    /// <param name="Element">
    /// パス構築用構造体
    /// </param>
    /// <param name="HCounter">
    /// 追加成功したカウンターのハンドル
    /// </param>
    /// <returns>
    /// 追加に成功したか否か
    /// </returns>
    function TryAddCounter(const Element: PPdhCounterPathElements;
      out HCounter: PDH_HCOUNTER): Boolean;

    /// <summary>
    /// 取得したメトリクスの詰め替え関数
    /// </summary>
    /// <param name="ExportList">
    /// 詰め替え先リスト
    /// </param>
    /// <param name="AConvertFunc">
    /// 変換仕様
    /// </param>
    procedure RefilList<TTarget>(const ExportList: TList<TTarget>;
      AConvertFunc: TFunc<TCollectedMetric, TPdhFmtType, TTarget>);
  end;

implementation

{ TCollectedMetric }

constructor TCollectedMetric.Create(const ACounterHandle: PDH_HCOUNTER;
  const AMetric: TPdhFmtCounterValue);
begin
  FCollectedDateTime := 0;
  FCounterHandle := 0;
  ZeroMemory(@FMetric, SizeOf(TPdhFmtCounterValue));

  FCollectedDateTime := Now();
  FCounterHandle := ACounterHandle;
  FMetric := AMetric;
end;

{ TMetricsCollectorThread }

function TMetricsCollectorThread.TryAddCounter(const Element
  : PPdhCounterPathElements; out HCounter: PDH_HCOUNTER): Boolean;
var
  Path: string;
begin
  Result := False;
  HCounter := 0;

  Result := TryMakeCounterPathFrom(Element, Path);
  if not Result then
  begin
    Exit();
  end;

  Result := Succeeded(PdhAddCounter(hQuery, PWideChar(Path), 0, HCounter));
  if not Result then
  begin
    Exit();
  end;

  if HCounter <> 0 then
  begin
    hCounters.Add(HCounter);
  end;
end;

constructor TMetricsCollectorThread.Create();
begin
  inherited Create(True);
  hQuery := 0;
  FIntervalMilSec := 1000;
  FreeOnTerminate := False;

  hCounters := nil;
  FCollectedMetricList := nil;
  FIntervalEvent := nil;

  PdhOpenQuery(nil, 0, hQuery);

  hCounters := TList<PDH_HCOUNTER>.Create();
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
  inherited;
end;

procedure TMetricsCollectorThread.DoIntervalEvent;
var
  IntervalTask: ITask;
begin
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

procedure TMetricsCollectorThread.Execute;
var
  Value: TPdhFmtCounterValue;
  Current: PDH_HCOUNTER;
begin
  TThread.NameThreadForDebugging(Self.ClassName);

  InitQuery();

  while not Terminated do
  begin

    PdhCollectQueryData(hQuery);

    for Current in hCounters do
    begin
      ZeroMemory(@Value, SizeOf(TPdhFmtCounterValue));
      PdhGetFormattedCounterValue(Current, PDH_FMT_DOUBLE, nil, Value);
      FCollectedMetricList.Add(TCollectedMetric.Create(Current, Value));
    end;

    DoIntervalEvent();
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

function TMetricsCollectorThread.TryMakeCounterPathFrom(const Element
  : PPdhCounterPathElements; var Path: string): Boolean;
var
  Buff: array [0 .. PDH_MAX_COUNTER_PATH] of WideChar;
  Size: DWORD;
  Ren: HRESULT;
begin
  Result := False;
  Path := EmptyStr;
  Size := 0;
  Ren := 0;
  ZeroMemory(@Buff, SizeOf(WideChar) * PDH_MAX_COUNTER_PATH);

  PdhMakeCounterPath(Element, Buff, Size, 0);
  Result := Succeeded(PdhMakeCounterPath(Element, Buff, Size, 0));
  if not Result then
  begin
    Exit();
  end;

  Path := WideCharToString(Buff);
end;

end.
