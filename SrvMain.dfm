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
  object Config: TXMLDocument
    FileName = '.\config.xml'
    Left = 88
    Top = 56
    DOMVendorDesc = 'MSXML'
  end
end
