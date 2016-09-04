unit SrvMainTests;

interface
uses
  DUnitX.TestFramework, SrvMain, System.SysUtils;

type

  [TestFixture]
  TSrvMainTests = class(TObject)
  private
    FSrv: TPerfService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    // Sample Methods
    // Simple single Test
    [Test]
    procedure Test1;
    // Test with TestCase Attribute to supply parameters.
    [Test]
    [TestCase('TestA','1,2')]
    [TestCase('TestB','3,4')]
    procedure Test2(const AValue1 : Integer;const AValue2 : Integer);
  end;

implementation

type
  TPerfServiceHelper = class helper for TPerfService
  public
    procedure SetListMax(const Max: Integer);
    procedure StrAddToList(const AStr: string);
  end;

procedure TSrvMainTests.Setup;
begin
  FSrv := nil;
  FSrv := TPerfService.Create(nil);
end;

procedure TSrvMainTests.TearDown;
begin
  FreeAndNil(FSrv);
end;

procedure TSrvMainTests.Test1;
begin
  FSrv.SetListMax(5);
end;

{ TPerfServiceHelper }

procedure TPerfServiceHelper.SetListMax(const Max: Integer);
begin
  Self.FCollectCounter := Max;
end;

procedure TPerfServiceHelper.StrAddToList(const AStr: string);
begin
  Self.FStrList.Add(AStr);
end;

initialization
  TDUnitX.RegisterTestFixture(TSrvMainTests);
end.
