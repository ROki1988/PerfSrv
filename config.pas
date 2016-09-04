{ *********************************** }
{ }
{ XML データバインディング }
{ }
{ 作成日： 2016/04/19 0:42:30 }
{ 作成元： Z:\config.xml }
{ 設定ファイルの保管先： Z:\config.xdb }
{ }
{ *********************************** }

unit config;

interface

uses xmldom, XMLDoc, XMLIntf, System.Generics.Collections;

type

  { 前方宣言 }

  IXMLConfigurationType = interface;
  IXMLConfigSectionsType = interface;
  IXMLSectionType = interface;
  IXMLCarbonatorType = interface;
  IXMLGraphiteType = interface;
  IXMLCountersType = interface;
  IXMLAddType = interface;
  IXMLAppenderType = interface;
  IXMLAppenderTypeList = interface;
  IXMLThresholdType = interface;
  IXMLParamType = interface;
  IXMLParamTypeList = interface;
  IXMLLayoutType = interface;
  IXMLRootType = interface;
  IXMLLevelType = interface;
  IXMLAppenderrefType = interface;
  IXMLAppenderrefTypeList = interface;

  { IXMLConfigurationType }

  IXMLConfigurationType = interface(IXMLNode)
    ['{D5075BDB-268B-4047-9B80-1BC31EBD90ED}']
    { プロパティ参照関数 }
    function Get_Carbonator: IXMLCarbonatorType;
    { メソッドとプロパティ }
    property Carbonator: IXMLCarbonatorType read Get_Carbonator;
  end;

  { IXMLConfigSectionsType }

  IXMLConfigSectionsType = interface(IXMLNodeCollection)
    ['{DCD164F6-7AC1-4404-BD15-C3CAC80B5B09}']
    { プロパティ参照関数 }
    function Get_Section(Index: Integer): IXMLSectionType;
    { メソッドとプロパティ }
    function Add: IXMLSectionType;
    function Insert(const Index: Integer): IXMLSectionType;
    property Section[Index: Integer]: IXMLSectionType read Get_Section; default;
  end;

  { IXMLSectionType }

  IXMLSectionType = interface(IXMLNode)
    ['{019D7F46-4164-47F3-B12C-44AD3C57414F}']
    { プロパティ参照関数 }
    function Get_Name: UnicodeString;
    function Get_Type_: UnicodeString;
    { メソッドとプロパティ }
    property Name: UnicodeString read Get_Name;
    property Type_: UnicodeString read Get_Type_;
  end;

  { IXMLCarbonatorType }

  IXMLCarbonatorType = interface(IXMLNode)
    ['{FE988041-AFFF-42F5-BC45-B1566FE4C6A4}']
    { プロパティ参照関数 }
    function Get_DefaultCulture: UnicodeString;
    function Get_LogLevel: Integer;
    function Get_LogType: UnicodeString;
    function Get_CollectionInterval: Integer;
    function Get_ReportingInterval: Integer;
    function Get_Graphite: IXMLGraphiteType;
    function Get_Counters: IXMLCountersType;
    { メソッドとプロパティ }
    property DefaultCulture: UnicodeString read Get_DefaultCulture;
    property LogLevel: Integer read Get_LogLevel;
    property LogType: UnicodeString read Get_LogType;
    property CollectionInterval: Integer read Get_CollectionInterval;
    property ReportingInterval: Integer read Get_ReportingInterval;
    property Graphite: IXMLGraphiteType read Get_Graphite;
    property Counters: IXMLCountersType read Get_Counters;
  end;

  { IXMLGraphiteType }

  IXMLGraphiteType = interface(IXMLNode)
    ['{3108A2FB-488A-440F-974F-C14EDDF47F9E}']
    { プロパティ参照関数 }
    function Get_Server: UnicodeString;
    function Get_Port: Integer;
    { メソッドとプロパティ }
    property Server: UnicodeString read Get_Server;
    property Port: Integer read Get_Port;
  end;

  { IXMLCountersType }

  IXMLCountersType = interface(IXMLNodeCollection)
    ['{A6CF1607-DABC-44A4-A32B-CCCB2395D911}']
    { プロパティ参照関数 }
    function Get_Add(Index: Integer): IXMLAddType;
    { メソッドとプロパティ }
    function Add: IXMLAddType;
    function Insert(const Index: Integer): IXMLAddType;
    property Add[Index: Integer]: IXMLAddType read Get_Add; default;
  end;

  { IXMLAddType }

  IXMLAddType = interface(IXMLNode)
    ['{CE7B970F-3E99-4A73-B399-C16C8723A342}']
    { プロパティ参照関数 }
    function Get_Path: UnicodeString;
    function Get_Category: UnicodeString;
    function Get_Counter: UnicodeString;
    function Get_Instance: UnicodeString;
    procedure Set_Path(Value: UnicodeString);
    procedure Set_Category(Value: UnicodeString);
    procedure Set_Counter(Value: UnicodeString);
    procedure Set_Instance(Value: UnicodeString);
    { メソッドとプロパティ }
    property Path: UnicodeString read Get_Path write Set_Path;
    property Category: UnicodeString read Get_Category write Set_Category;
    property Counter: UnicodeString read Get_Counter write Set_Counter;
    property Instance: UnicodeString read Get_Instance write Set_Instance;
  end;

  { IXMLAppenderType }

  IXMLAppenderType = interface(IXMLNode)
    ['{F9165592-45FB-4474-BD62-170EB2708A87}']
    { プロパティ参照関数 }
    function Get_Name: UnicodeString;
    function Get_Type_: UnicodeString;
    function Get_Threshold: IXMLThresholdType;
    function Get_Param: IXMLParamTypeList;
    function Get_Layout: IXMLLayoutType;
    { メソッドとプロパティ }
    property Name: UnicodeString read Get_Name;
    property Type_: UnicodeString read Get_Type_;
    property Threshold: IXMLThresholdType read Get_Threshold;
    property Param: IXMLParamTypeList read Get_Param;
    property Layout: IXMLLayoutType read Get_Layout;
  end;

  { IXMLAppenderTypeList }

  IXMLAppenderTypeList = interface(IXMLNodeCollection)
    ['{9EEDCD63-FC14-43E3-B8E4-409028243D14}']
    { メソッドとプロパティ }
    function Add: IXMLAppenderType;
    function Insert(const Index: Integer): IXMLAppenderType;

    function Get_Item(Index: Integer): IXMLAppenderType;
    property Items[Index: Integer]: IXMLAppenderType read Get_Item; default;
  end;

  { IXMLThresholdType }

  IXMLThresholdType = interface(IXMLNode)
    ['{DF6916EA-D728-416E-BD0C-379EDCF17C7D}']
    { プロパティ参照関数 }
    function Get_Value: UnicodeString;
    { メソッドとプロパティ }
    property Value: UnicodeString read Get_Value;
  end;

  { IXMLParamType }

  IXMLParamType = interface(IXMLNode)
    ['{7B224165-6E43-42E2-A5F0-BCBF018CDC81}']
    { プロパティ参照関数 }
    function Get_Name: UnicodeString;
    function Get_Value: UnicodeString;
    { メソッドとプロパティ }
    property Name: UnicodeString read Get_Name;
    property Value: UnicodeString read Get_Value;
  end;

  { IXMLParamTypeList }

  IXMLParamTypeList = interface(IXMLNodeCollection)
    ['{DE1E73CE-5C60-43FB-8B82-D44A9BDF0952}']
    { メソッドとプロパティ }
    function Add: IXMLParamType;
    function Insert(const Index: Integer): IXMLParamType;

    function Get_Item(Index: Integer): IXMLParamType;
    property Items[Index: Integer]: IXMLParamType read Get_Item; default;
  end;

  { IXMLLayoutType }

  IXMLLayoutType = interface(IXMLNodeCollection)
    ['{0B3A28E9-D844-4421-B693-7927D6414261}']
    { プロパティ参照関数 }
    function Get_Type_: UnicodeString;
    function Get_Param(Index: Integer): IXMLParamType;
    { メソッドとプロパティ }
    function Add: IXMLParamType;
    function Insert(const Index: Integer): IXMLParamType;
    property Type_: UnicodeString read Get_Type_;
    property Param[Index: Integer]: IXMLParamType read Get_Param; default;
  end;

  { IXMLRootType }

  IXMLRootType = interface(IXMLNode)
    ['{75858D57-121C-4699-B896-6A46A8E8D45D}']
    { プロパティ参照関数 }
    function Get_Level: IXMLLevelType;
    function Get_Appenderref: IXMLAppenderrefTypeList;
    { メソッドとプロパティ }
    property Level: IXMLLevelType read Get_Level;
    property Appenderref: IXMLAppenderrefTypeList read Get_Appenderref;
  end;

  { IXMLLevelType }

  IXMLLevelType = interface(IXMLNode)
    ['{9926C05B-FC65-4377-BDB8-EACFEA2EFF6B}']
    { プロパティ参照関数 }
    function Get_Value: UnicodeString;
    { メソッドとプロパティ }
    property Value: UnicodeString read Get_Value;
  end;

  { IXMLAppenderrefType }

  IXMLAppenderrefType = interface(IXMLNode)
    ['{497AEFFB-E9C3-4AD6-B81C-C3936A1216D4}']
    { プロパティ参照関数 }
    function Get_Ref: UnicodeString;
    { メソッドとプロパティ }
    property Ref: UnicodeString read Get_Ref;
  end;

  { IXMLAppenderrefTypeList }

  IXMLAppenderrefTypeList = interface(IXMLNodeCollection)
    ['{CEFE6FF1-07C3-4906-83AD-84FD69909AD3}']
    { メソッドとプロパティ }
    function Add: IXMLAppenderrefType;
    function Insert(const Index: Integer): IXMLAppenderrefType;

    function Get_Item(Index: Integer): IXMLAppenderrefType;
    property Items[Index: Integer]: IXMLAppenderrefType read Get_Item; default;
  end;

  { 前方宣言 }

  TXMLConfigurationType = class;
  TXMLConfigSectionsType = class;
  TXMLSectionType = class;
  TXMLCarbonatorType = class;
  TXMLGraphiteType = class;
  TXMLCountersType = class;
  TXMLAddType = class;
  TXMLAppenderType = class;
  TXMLAppenderTypeList = class;
  TXMLThresholdType = class;
  TXMLParamType = class;
  TXMLParamTypeList = class;
  TXMLLayoutType = class;
  TXMLRootType = class;
  TXMLLevelType = class;
  TXMLAppenderrefType = class;
  TXMLAppenderrefTypeList = class;

  { TXMLConfigurationType }

  TXMLConfigurationType = class(TXMLNode, IXMLConfigurationType)
  protected
    { IXMLConfigurationType }
    function Get_Carbonator: IXMLCarbonatorType;
  public
    procedure AfterConstruction; override;
  end;

  { TXMLConfigSectionsType }

  TXMLConfigSectionsType = class(TXMLNodeCollection, IXMLConfigSectionsType)
  protected
    { IXMLConfigSectionsType }
    function Get_Section(Index: Integer): IXMLSectionType;
    function Add: IXMLSectionType;
    function Insert(const Index: Integer): IXMLSectionType;
  public
    procedure AfterConstruction; override;
  end;

  { TXMLSectionType }

  TXMLSectionType = class(TXMLNode, IXMLSectionType)
  protected
    { IXMLSectionType }
    function Get_Name: UnicodeString;
    function Get_Type_: UnicodeString;
  end;

  { TXMLCarbonatorType }

  TXMLCarbonatorType = class(TXMLNode, IXMLCarbonatorType)
  protected
    { IXMLCarbonatorType }
    function Get_DefaultCulture: UnicodeString;
    function Get_LogLevel: Integer;
    function Get_LogType: UnicodeString;
    function Get_CollectionInterval: Integer;
    function Get_ReportingInterval: Integer;
    function Get_Graphite: IXMLGraphiteType;
    function Get_Counters: IXMLCountersType;
  public
    procedure AfterConstruction; override;
  end;

  { TXMLGraphiteType }

  TXMLGraphiteType = class(TXMLNode, IXMLGraphiteType)
  protected
    { IXMLGraphiteType }
    function Get_Server: UnicodeString;
    function Get_Port: Integer;
  end;

  { TXMLCountersType }

  TXMLCountersType = class(TXMLNodeCollection, IXMLCountersType)
  protected
    { IXMLCountersType }
    function Get_Add(Index: Integer): IXMLAddType;
    function Add: IXMLAddType;
    function Insert(const Index: Integer): IXMLAddType;
  public
    procedure AfterConstruction; override;
  end;

  { TXMLAddType }

  TXMLAddType = class(TXMLNode, IXMLAddType)
  protected
    { IXMLAddType }
    function Get_Path: UnicodeString;
    function Get_Category: UnicodeString;
    function Get_Counter: UnicodeString;
    function Get_Instance: UnicodeString;
    procedure Set_Path(Value: UnicodeString);
    procedure Set_Category(Value: UnicodeString);
    procedure Set_Counter(Value: UnicodeString);
    procedure Set_Instance(Value: UnicodeString);
  end;

  { TXMLAppenderType }

  TXMLAppenderType = class(TXMLNode, IXMLAppenderType)
  private
    FParam: IXMLParamTypeList;
  protected
    { IXMLAppenderType }
    function Get_Name: UnicodeString;
    function Get_Type_: UnicodeString;
    function Get_Threshold: IXMLThresholdType;
    function Get_Param: IXMLParamTypeList;
    function Get_Layout: IXMLLayoutType;
  public
    procedure AfterConstruction; override;
  end;

  { TXMLAppenderTypeList }

  TXMLAppenderTypeList = class(TXMLNodeCollection, IXMLAppenderTypeList)
  protected
    { IXMLAppenderTypeList }
    function Add: IXMLAppenderType;
    function Insert(const Index: Integer): IXMLAppenderType;

    function Get_Item(Index: Integer): IXMLAppenderType;
  end;

  { TXMLThresholdType }

  TXMLThresholdType = class(TXMLNode, IXMLThresholdType)
  protected
    { IXMLThresholdType }
    function Get_Value: UnicodeString;
  end;

  { TXMLParamType }

  TXMLParamType = class(TXMLNode, IXMLParamType)
  protected
    { IXMLParamType }
    function Get_Name: UnicodeString;
    function Get_Value: UnicodeString;
  end;

  { TXMLParamTypeList }

  TXMLParamTypeList = class(TXMLNodeCollection, IXMLParamTypeList)
  protected
    { IXMLParamTypeList }
    function Add: IXMLParamType;
    function Insert(const Index: Integer): IXMLParamType;

    function Get_Item(Index: Integer): IXMLParamType;
  end;

  { TXMLLayoutType }

  TXMLLayoutType = class(TXMLNodeCollection, IXMLLayoutType)
  protected
    { IXMLLayoutType }
    function Get_Type_: UnicodeString;
    function Get_Param(Index: Integer): IXMLParamType;
    function Add: IXMLParamType;
    function Insert(const Index: Integer): IXMLParamType;
  public
    procedure AfterConstruction; override;
  end;

  { TXMLRootType }

  TXMLRootType = class(TXMLNode, IXMLRootType)
  private
    FAppenderref: IXMLAppenderrefTypeList;
  protected
    { IXMLRootType }
    function Get_Level: IXMLLevelType;
    function Get_Appenderref: IXMLAppenderrefTypeList;
  public
    procedure AfterConstruction; override;
  end;

  { TXMLLevelType }

  TXMLLevelType = class(TXMLNode, IXMLLevelType)
  protected
    { IXMLLevelType }
    function Get_Value: UnicodeString;
  end;

  { TXMLAppenderrefType }

  TXMLAppenderrefType = class(TXMLNode, IXMLAppenderrefType)
  protected
    { IXMLAppenderrefType }
    function Get_Ref: UnicodeString;
  end;

  { TXMLAppenderrefTypeList }

  TXMLAppenderrefTypeList = class(TXMLNodeCollection, IXMLAppenderrefTypeList)
  protected
    { IXMLAppenderrefTypeList }
    function Add: IXMLAppenderrefType;
    function Insert(const Index: Integer): IXMLAppenderrefType;

    function Get_Item(Index: Integer): IXMLAppenderrefType;
  end;

  { グローバル関数 }

function Getconfiguration(Doc: IXMLDocument): IXMLConfigurationType;
function Loadconfiguration(const FileName: string): IXMLConfigurationType;
function Newconfiguration: IXMLConfigurationType;

const
  TargetNamespace = '';

implementation

{ グローバル関数 }

function Getconfiguration(Doc: IXMLDocument): IXMLConfigurationType;
begin
  Result := Doc.GetDocBinding('configuration', TXMLConfigurationType,
    TargetNamespace) as IXMLConfigurationType;
end;

function Loadconfiguration(const FileName: string): IXMLConfigurationType;
begin
  Result := LoadXMLDocument(FileName).GetDocBinding('configuration',
    TXMLConfigurationType, TargetNamespace) as IXMLConfigurationType;
end;

function Newconfiguration: IXMLConfigurationType;
begin
  Result := NewXMLDocument.GetDocBinding('configuration', TXMLConfigurationType,
    TargetNamespace) as IXMLConfigurationType;
end;

{ TXMLConfigurationType }

procedure TXMLConfigurationType.AfterConstruction;
begin
  RegisterChildNode('carbonator', TXMLCarbonatorType);
  inherited;
end;

function TXMLConfigurationType.Get_Carbonator: IXMLCarbonatorType;
begin
  Result := ChildNodes['carbonator'] as IXMLCarbonatorType;
end;

{ TXMLConfigSectionsType }

procedure TXMLConfigSectionsType.AfterConstruction;
begin
  RegisterChildNode('section', TXMLSectionType);
  ItemTag := 'section';
  ItemInterface := IXMLSectionType;
  inherited;
end;

function TXMLConfigSectionsType.Get_Section(Index: Integer): IXMLSectionType;
begin
  Result := List[Index] as IXMLSectionType;
end;

function TXMLConfigSectionsType.Add: IXMLSectionType;
begin
  Result := AddItem(-1) as IXMLSectionType;
end;

function TXMLConfigSectionsType.Insert(const Index: Integer): IXMLSectionType;
begin
  Result := AddItem(Index) as IXMLSectionType;
end;

{ TXMLSectionType }

function TXMLSectionType.Get_Name: UnicodeString;
begin
  Result := AttributeNodes['name'].Text;
end;

function TXMLSectionType.Get_Type_: UnicodeString;
begin
  Result := AttributeNodes['type'].Text;
end;

{ TXMLCarbonatorType }

procedure TXMLCarbonatorType.AfterConstruction;
begin
  RegisterChildNode('graphite', TXMLGraphiteType);
  RegisterChildNode('counters', TXMLCountersType);
  inherited;
end;

function TXMLCarbonatorType.Get_DefaultCulture: UnicodeString;
begin
  Result := AttributeNodes['defaultCulture'].Text;
end;

function TXMLCarbonatorType.Get_LogLevel: Integer;
begin
  Result := AttributeNodes['logLevel'].NodeValue;
end;

function TXMLCarbonatorType.Get_LogType: UnicodeString;
begin
  Result := AttributeNodes['logType'].Text;
end;

function TXMLCarbonatorType.Get_CollectionInterval: Integer;
begin
  Result := AttributeNodes['collectionInterval'].NodeValue;
end;

function TXMLCarbonatorType.Get_ReportingInterval: Integer;
begin
  Result := AttributeNodes['reportingInterval'].NodeValue;
end;

function TXMLCarbonatorType.Get_Graphite: IXMLGraphiteType;
begin
  Result := ChildNodes['graphite'] as IXMLGraphiteType;
end;

function TXMLCarbonatorType.Get_Counters: IXMLCountersType;
begin
  Result := ChildNodes['counters'] as IXMLCountersType;
end;

{ TXMLGraphiteType }

function TXMLGraphiteType.Get_Server: UnicodeString;
begin
  Result := AttributeNodes['server'].Text;
end;

function TXMLGraphiteType.Get_Port: Integer;
begin
  Result := AttributeNodes['port'].NodeValue;
end;

{ TXMLCountersType }

procedure TXMLCountersType.AfterConstruction;
begin
  RegisterChildNode('add', TXMLAddType);
  ItemTag := 'add';
  ItemInterface := IXMLAddType;
  inherited;
end;

function TXMLCountersType.Get_Add(Index: Integer): IXMLAddType;
begin
  Result := List[Index] as IXMLAddType;
end;

function TXMLCountersType.Add: IXMLAddType;
begin
  Result := AddItem(-1) as IXMLAddType;
end;

function TXMLCountersType.Insert(const Index: Integer): IXMLAddType;
begin
  Result := AddItem(Index) as IXMLAddType;
end;

{ TXMLAddType }

function TXMLAddType.Get_Path: UnicodeString;
begin
  Result := AttributeNodes['path'].Text;
end;

procedure TXMLAddType.Set_Path(Value: UnicodeString);
begin
  SetAttribute('path', Value);
end;

function TXMLAddType.Get_Category: UnicodeString;
begin
  Result := AttributeNodes['category'].Text;
end;

procedure TXMLAddType.Set_Category(Value: UnicodeString);
begin
  SetAttribute('category', Value);
end;

function TXMLAddType.Get_Counter: UnicodeString;
begin
  Result := AttributeNodes['counter'].Text;
end;

procedure TXMLAddType.Set_Counter(Value: UnicodeString);
begin
  SetAttribute('counter', Value);
end;

function TXMLAddType.Get_Instance: UnicodeString;
begin
  Result := AttributeNodes['instance'].Text;
end;

procedure TXMLAddType.Set_Instance(Value: UnicodeString);
begin
  SetAttribute('instance', Value);
end;

{ TXMLAppenderType }

procedure TXMLAppenderType.AfterConstruction;
begin
  RegisterChildNode('threshold', TXMLThresholdType);
  RegisterChildNode('param', TXMLParamType);
  RegisterChildNode('layout', TXMLLayoutType);
  FParam := CreateCollection(TXMLParamTypeList, IXMLParamType, 'param')
    as IXMLParamTypeList;
  inherited;
end;

function TXMLAppenderType.Get_Name: UnicodeString;
begin
  Result := AttributeNodes['name'].Text;
end;

function TXMLAppenderType.Get_Type_: UnicodeString;
begin
  Result := AttributeNodes['type'].Text;
end;

function TXMLAppenderType.Get_Threshold: IXMLThresholdType;
begin
  Result := ChildNodes['threshold'] as IXMLThresholdType;
end;

function TXMLAppenderType.Get_Param: IXMLParamTypeList;
begin
  Result := FParam;
end;

function TXMLAppenderType.Get_Layout: IXMLLayoutType;
begin
  Result := ChildNodes['layout'] as IXMLLayoutType;
end;

{ TXMLAppenderTypeList }

function TXMLAppenderTypeList.Add: IXMLAppenderType;
begin
  Result := AddItem(-1) as IXMLAppenderType;
end;

function TXMLAppenderTypeList.Insert(const Index: Integer): IXMLAppenderType;
begin
  Result := AddItem(Index) as IXMLAppenderType;
end;

function TXMLAppenderTypeList.Get_Item(Index: Integer): IXMLAppenderType;
begin
  Result := List[Index] as IXMLAppenderType;
end;

{ TXMLThresholdType }

function TXMLThresholdType.Get_Value: UnicodeString;
begin
  Result := AttributeNodes['value'].Text;
end;

{ TXMLParamType }

function TXMLParamType.Get_Name: UnicodeString;
begin
  Result := AttributeNodes['name'].Text;
end;

function TXMLParamType.Get_Value: UnicodeString;
begin
  Result := AttributeNodes['value'].Text;
end;

{ TXMLParamTypeList }

function TXMLParamTypeList.Add: IXMLParamType;
begin
  Result := AddItem(-1) as IXMLParamType;
end;

function TXMLParamTypeList.Insert(const Index: Integer): IXMLParamType;
begin
  Result := AddItem(Index) as IXMLParamType;
end;

function TXMLParamTypeList.Get_Item(Index: Integer): IXMLParamType;
begin
  Result := List[Index] as IXMLParamType;
end;

{ TXMLLayoutType }

procedure TXMLLayoutType.AfterConstruction;
begin
  RegisterChildNode('param', TXMLParamType);
  ItemTag := 'param';
  ItemInterface := IXMLParamType;
  inherited;
end;

function TXMLLayoutType.Get_Type_: UnicodeString;
begin
  Result := AttributeNodes['type'].Text;
end;

function TXMLLayoutType.Get_Param(Index: Integer): IXMLParamType;
begin
  Result := List[Index] as IXMLParamType;
end;

function TXMLLayoutType.Add: IXMLParamType;
begin
  Result := AddItem(-1) as IXMLParamType;
end;

function TXMLLayoutType.Insert(const Index: Integer): IXMLParamType;
begin
  Result := AddItem(Index) as IXMLParamType;
end;

{ TXMLRootType }

procedure TXMLRootType.AfterConstruction;
begin
  RegisterChildNode('level', TXMLLevelType);
  RegisterChildNode('appender-ref', TXMLAppenderrefType);
  FAppenderref := CreateCollection(TXMLAppenderrefTypeList, IXMLAppenderrefType,
    'appender-ref') as IXMLAppenderrefTypeList;
  inherited;
end;

function TXMLRootType.Get_Level: IXMLLevelType;
begin
  Result := ChildNodes['level'] as IXMLLevelType;
end;

function TXMLRootType.Get_Appenderref: IXMLAppenderrefTypeList;
begin
  Result := FAppenderref;
end;

{ TXMLLevelType }

function TXMLLevelType.Get_Value: UnicodeString;
begin
  Result := AttributeNodes['value'].Text;
end;

{ TXMLAppenderrefType }

function TXMLAppenderrefType.Get_Ref: UnicodeString;
begin
  Result := AttributeNodes['ref'].Text;
end;

{ TXMLAppenderrefTypeList }

function TXMLAppenderrefTypeList.Add: IXMLAppenderrefType;
begin
  Result := AddItem(-1) as IXMLAppenderrefType;
end;

function TXMLAppenderrefTypeList.Insert(const Index: Integer)
  : IXMLAppenderrefType;
begin
  Result := AddItem(Index) as IXMLAppenderrefType;
end;

function TXMLAppenderrefTypeList.Get_Item(Index: Integer): IXMLAppenderrefType;
begin
  Result := List[Index] as IXMLAppenderrefType;
end;

end.
