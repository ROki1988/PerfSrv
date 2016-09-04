unit TestTcpSendThead;

interface

uses
  DUnitX.TestFramework, TcpSendThread, System.SysUtils;

type

  [TestFixture]
  TTestTcpSendThead = class(TObject)
  strict private
  strict private
    FThread: TTcpSendThread;
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
  end;

implementation

uses
  IdGlobal;

procedure TTestTcpSendThead.Setup;
begin
  FThread := nil;
  FThread := TTcpSendThread.Create(True, 'localhost', 55056, 100, 100, encASCII);
end;

procedure TTestTcpSendThead.TearDown;
begin
  FThread.Terminate();
  FreeAndNil(FThread);
end;

procedure TTestTcpSendThead.Test1;
begin
  FThread.AddSendData('Test');
end;

initialization

TDUnitX.RegisterTestFixture(TTestTcpSendThead);

end.
