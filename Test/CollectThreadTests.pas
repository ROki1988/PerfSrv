unit CollectThreadTests;

interface

uses
  DUnitX.TestFramework, CollectMetric, System.SysUtils, Winapi.Windows;

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

    [TestCase('valid pattern', 'Processor,% Processor Time,_Total')]
    procedure Test(const Category, Counter, Instance: string);

  end;

implementation

uses
  JwaPdh;

procedure TMyTestObject.Setup;
begin
  FThread := nil;
  FThread := TMetricsCollectorThread.Create(100, nil);
end;

procedure TMyTestObject.TearDown;
begin
  FThread.Terminate;
  FreeAndNil(FThread);
end;

procedure TMyTestObject.Test(const Category, Counter, Instance: string);
var
  hCounter: PDH_HCOUNTER;
  AddCounter: TPdhCounterPathElements;
begin
  ZeroMemory(@AddCounter, SizeOf(TPdhCounterPathElements));
  AddCounter.szObjectName := PWideChar(Category);

  if not string.IsNullOrWhiteSpace(Counter) then
  begin
    AddCounter.szCounterName := PWideChar(Counter);
  end;

  if not string.IsNullOrWhiteSpace(Instance) then
  begin
    AddCounter.szInstanceName := PWideChar(Instance);
  end;

  Assert.IsTrue(FThread.TryAddCounter(@AddCounter, hCounter));
  Assert.AreNotEqual(hCounter, PDH_HCOUNTER(0));
end;

initialization

TDUnitX.RegisterTestFixture(TMyTestObject);

end.
