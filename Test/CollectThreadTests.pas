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

    [TestCase('valid pattern', 'perf,send,1')]
    procedure Test(const Path, SendPath: string; Counter: Integer);

  end;

implementation

type
  TMetricsCollectorThreadHelper = class helper for TMetricsCollectorThread
  public
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

procedure TMyTestObject.Test(const Path, SendPath: string; Counter: Integer);
begin
  FThread.AddCounter(Path, SendPath);
  Assert.AreEqual(FThread.GetPathPairConunt(), Counter);
end;

{ TMetricsCollectorThread }

function TMetricsCollectorThreadHelper.GetPathPairConunt: Integer;
begin
  Result := 0;
  Result := Self.FCounterPathPairs.Count;
end;

initialization

TDUnitX.RegisterTestFixture(TMyTestObject);

end.
