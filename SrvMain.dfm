object PerfService: TPerfService
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = 'PerfSvc'
  OnContinue = ServiceContinue
  OnExecute = ServiceExecute
  OnPause = ServicePause
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
  object IdUDPClient1: TIdUDPClient
    Port = 0
    OnConnected = IdUDPClient1Connected
    OnDisconnected = IdUDPClient1Disconnected
  end
end
