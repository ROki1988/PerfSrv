unit ObjectUtils;

interface

type
  TObjectHelper = class helper for TObject
    class function TryCastTo<TTarget: class>(const Source: TObject;
      var Dest: TTarget): Boolean;
  end;

implementation

{ TObjectHelper }

class function TObjectHelper.TryCastTo<TTarget>(const Source: TObject;
  var Dest: TTarget): Boolean;
begin
  Result := False;
  Dest := nil;

  Result := Assigned(Source) and (Source is TTarget);
  if Result then
  begin
    Dest := TTarget(Source);
  end;
end;

end.
