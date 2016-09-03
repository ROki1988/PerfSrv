unit TcpSendThread;

interface

uses
  System.Classes, System.SysUtils, Generics.Collections, IdBaseComponent,
  IdComponent, IdUDPBase, IdUDPClient,
  System.StrUtils, IdGlobal;

type
  TLoopState = (lsNone, lsContinue, lsExit);

type
  TTcpSendThread = class(TThread)
  strict protected
    FSendStrList: TThreadList<string>;
    FSendIntervalMSec: Integer;
    FSender: TIdUDPClient;
    FMaxStateCounter: Integer;
    FEncodeType: IdTextEncodingType;

    FLoopFunc: function: TLoopState of object;
    FLoopCount: Integer;

    function Func4Connected(): TLoopState;
    function Func4DisConnected(): TLoopState;

    procedure SendMetric();

    procedure SenderOnConnected(Sender: TObject);
    procedure SenderOnDisconnected(Sender: TObject);

  const
    INTERVAL = 100;
  protected
    procedure Execute(); override;
  public
    constructor Create(const CreateSuspended: Boolean;
  const HostAddr: string; HostPort, SendIntervalMSec, MaxStateCounter: Integer; const EncodeType: IdTextEncodingType);
    destructor Destroy; override;
    procedure AddSendData(const Data: string); overload;
    procedure AddSendData(const Data: TList<string>); overload;
  end;

implementation

{ TTcpSendThread }

procedure TTcpSendThread.AddSendData(const Data: string);
var
  StrList: TList<string>;
begin
  StrList := FSendStrList.LockList();
  try
    StrList.Add(Data);
    if StrList.Count > FMaxStateCounter then
    begin
      StrList.DeleteRange(0, StrList.Count - FMaxStateCounter);
    end;
  finally
    FSendStrList.UnlockList();
  end;
end;

procedure TTcpSendThread.AddSendData(const Data: TList<string>);
var
  StrList: TList<string>;
begin
  StrList := FSendStrList.LockList();
  try
    StrList.AddRange(Data);
    if StrList.Count > FMaxStateCounter then
    begin
      StrList.DeleteRange(0, StrList.Count - FMaxStateCounter);
    end;
  finally
    FSendStrList.UnlockList();
  end;
end;

constructor TTcpSendThread.Create(const CreateSuspended: Boolean;
  const HostAddr: string; HostPort, SendIntervalMSec, MaxStateCounter: Integer; const EncodeType: IdTextEncodingType);
begin
  inherited Create(CreateSuspended);
  FreeOnTerminate := False;
  FSendIntervalMSec := 1000;
  FSender := nil;
  FSendStrList := nil;

  FSendIntervalMSec := SendIntervalMSec;
  FSendStrList := TThreadList<string>.Create();
  FSender := TIdUDPClient.Create();

  FSender.Host := HostAddr;
  FSender.Port := HostPort;
  FMaxStateCounter := MaxStateCounter;
  FEncodeType := EncodeType;

  FSender.OnConnected := SenderOnConnected;
  FSender.OnDisconnected := SenderOnDisconnected;

  FLoopFunc := Func4DisConnected;
end;

destructor TTcpSendThread.Destroy;
begin
  FreeAndNil(FSender);
  FreeAndNil(FSendStrList);

  inherited;
end;

procedure TTcpSendThread.Execute;
var
  LoopState: TLoopState;
begin
  FLoopCount := 0;

  while not Terminated do
  begin
    LoopState := lsNone;

    if Assigned(FLoopFunc) then
    begin
      LoopState := FLoopFunc();
    end;

    case LoopState of
      lsNone:
        ;
      lsContinue:
        Continue;
      lsExit:
        Exit;
    end;

    Sleep(INTERVAL);
  end;
end;

function TTcpSendThread.Func4Connected: TLoopState;
begin
  Result := lsNone;

  if FLoopCount * INTERVAL < FSendIntervalMSec then
  begin
    Inc(FLoopCount);
  end
  else
  begin
    SendMetric();
    FLoopCount := 0;
  end;
end;

function TTcpSendThread.Func4DisConnected: TLoopState;
begin
  Result := lsNone;

  if not FSender.Connected then
  begin
    FSender.Connect;
  end;
end;

procedure TTcpSendThread.SenderOnConnected(Sender: TObject);
begin
  FLoopFunc := Func4Connected;
end;

procedure TTcpSendThread.SenderOnDisconnected(Sender: TObject);
begin
  FLoopFunc := Func4DisConnected;
end;

procedure TTcpSendThread.SendMetric;
var
  StrList: TList<string>;
  CurrentStr: string;
begin
  StrList := FSendStrList.LockList();
  try
    for CurrentStr in StrList do
    begin
      FSender.Send(CurrentStr, IndyTextEncoding(FEncodeType));
    end;
    StrList.Clear();
  finally
    FSendStrList.UnlockList();
  end;
end;

end.
