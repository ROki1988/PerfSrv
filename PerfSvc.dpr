program PerfSvc;

uses
  Vcl.SvcMgr,
  SrvMain in 'SrvMain.pas' {PerfService: TService},
  CollectMetric in 'CollectMetric.pas',
  config in 'config.pas',
  ObjectUtils in 'ObjectUtils.pas',
  TcpSendThread in 'TcpSendThread.pas';

{$R *.RES}

begin
  // Windows 2003 Server �ł́ACoRegisterClassObject �̑O�� StartServiceCtrlDispatcher ��
  // �Ăяo���K�v������܂��B�O�҂� Application.Initialize �ŊԐړI��
  // �Ăяo����邱�Ƃ�����܂��BTServiceApplication.DelayInitialize �ł́A
  // (StartServiceCtrlDispatcher ���Ăяo���ꂽ���) TService.Main ����
  // Application.Initialize ���Ăяo�����Ƃ��ł��܂��B
  //
  // Application �I�u�W�F�N�g�̒x���������́A���������O�ɔ�������
  // �C�x���g (���Ƃ��� TService.OnCreate �Ȃ�) �ɉe�����y�ڂ�
  // �\��������܂��B����𐄏�����̂́AServiceApplication ���A
  // Windows 2003 Server �Ŏg�p���邽�߂̂��̂ŁA���� OLE ��
  // �N���X �I�u�W�F�N�g��o�^����ꍇ�����ł��B
  //
  // Application.DelayInitialize := True;
  //
  if not Application.DelayInitialize or Application.Installing then
    Application.Initialize;
  Application.CreateForm(TPerfService, PerfService);
  Application.Run;

end.
