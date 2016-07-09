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
end
