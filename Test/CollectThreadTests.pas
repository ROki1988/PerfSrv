unit CollectThreadTests;

interface

uses
  DUnitX.TestFramework, CollectMetric, System.SysUtils;

type

  [TestFixture]
  TMyTestObject = class(TObject)
  private
    FThread: TMetricsCollectorThread;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [TestCase('valid pattern', 'Processor,% Processor Time,_Total,hogehoge,1')]
    procedure Test(const Category, Counter, Instance, SendPath: string; ListCounter: Integer);

  end;

implementation

type
  TMetricsCollectorThreadHelper = class helper for TMetricsCollectorThread
  public
    function GetCollectMetricFromTest(const Category, Counter, Instance
      : string): string;
    function GetPathPairConunt: Integer;
  end;

procedure TMyTestObject.Setup;
begin
  FThread := nil;
  FThread := TMetricsCollectorThread.Create();
end;

procedure TMyTestObject.TearDown;
begin
  FThread.Terminate;
  FreeAndNil(FThread);
end;

procedure TMyTestObject.Test(const Category, Counter, Instance, SendPath: string; ListCounter: Integer);
begin
  FThread.AddCounter(Category, Counter, Instance, SendPath);
  Assert.AreEqual(FThread.GetPathPairConunt(), ListCounter);
end;

{ TMetricsCollectorThread }

function TMetricsCollectorThreadHelper.GetCollectMetricFromTest(const Category,
  Counter, Instance: string): string;
begin
  Result := Self.GetCollectMetricFromTest(Category, Counter, Instance);
end;

function TMetricsCollectorThreadHelper.GetPathPairConunt: Integer;
begin
  Result := 0;
  Result := Self.FCounterPathPairs.Count;
end;

initialization

TDUnitX.RegisterTestFixture(TMyTestObject);

end.
