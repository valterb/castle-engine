{ -*- buffer-read-only: t -*-

  Copyright 2015-2020 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Automatically generated node properties.

  Do not edit this file manually!
  To add new properties:
  - add them to the text files in tools/internal/x3d-nodes-to-pascal/nodes-specification/ ,
  - and regenerate include files by running x3d-nodes-to-pascal .

  The documentation for properties should go to x3dnodes_documentation.txt . }

{$ifdef read_interface}

  strict private
    function GetCenterOfMass: TVector3;
    procedure SetCenterOfMass(const Value: TVector3);
    function GetCoord: TAbstractCoordinateNode;
    procedure SetCoord(const Value: TAbstractCoordinateNode);
    function GetMass: Single;
    procedure SetMass(const Value: Single);
    function GetNameField: String;
    procedure SetNameField(const Value: String);
    function GetRotation: TVector4;
    procedure SetRotation(const Value: TVector4);
    function GetScale: TVector3;
    procedure SetScale(const Value: TVector3);
    function GetTranslation: TVector3;
    procedure SetTranslation(const Value: TVector3);
  public
    { X3D field "centerOfMass". } { }
    property CenterOfMass: TVector3 read GetCenterOfMass write SetCenterOfMass;
    { X3D field "coord". } { }
    property Coord: TAbstractCoordinateNode read GetCoord write SetCoord;
    { Set X3D field "displacers". } { }
    procedure SetDisplacers(const Value: array of THAnimDisplacerNode);
    { X3D field "mass". } { }
    property Mass: Single read GetMass write SetMass;
    { Set X3D field "momentsOfInertia". } { }
    procedure SetMomentsOfInertia(const Value: array of Single);
    { Set X3D field "momentsOfInertia". } { }
    procedure SetMomentsOfInertia(const Value: TSingleList);
    { X3D field "name". } { }
    property NameField: String read GetNameField write SetNameField;
    { X3D field "rotation". } { }
    property Rotation: TVector4 read GetRotation write SetRotation;
    { X3D field "scale". } { }
    property Scale: TVector3 read GetScale write SetScale;
    { X3D field "translation". } { }
    property Translation: TVector3 read GetTranslation write SetTranslation;

{$endif read_interface}

{$ifdef read_implementation}

{ THAnimSegmentNode ----------------------------------------------- }

function THAnimSegmentNode.GetCenterOfMass: TVector3;
begin
  Result := FdCenterOfMass.Value;
end;

procedure THAnimSegmentNode.SetCenterOfMass(const Value: TVector3);
begin
  FdCenterOfMass.Send(Value);
end;

function THAnimSegmentNode.GetCoord: TAbstractCoordinateNode;
begin
  if FdCoord.Value is TAbstractCoordinateNode then
    Result := TAbstractCoordinateNode(FdCoord.Value)
  else
    Result := nil;
end;

procedure THAnimSegmentNode.SetCoord(const Value: TAbstractCoordinateNode);
begin
  FdCoord.Send(Value);
end;

procedure THAnimSegmentNode.SetDisplacers(const Value: array of THAnimDisplacerNode);
var
  L: Integer;
  A: array of TX3DNode;
begin
  L := High(Value) + 1;
  SetLength(A, L);
  if L > 0 then
    Move(Value[0], A[0], L * SizeOf(THAnimDisplacerNode));
  FdDisplacers.Send(A);
end;

function THAnimSegmentNode.GetMass: Single;
begin
  Result := FdMass.Value;
end;

procedure THAnimSegmentNode.SetMass(const Value: Single);
begin
  FdMass.Send(Value);
end;

procedure THAnimSegmentNode.SetMomentsOfInertia(const Value: array of Single);
begin
  FdMomentsOfInertia.Send(Value);
end;

procedure THAnimSegmentNode.SetMomentsOfInertia(const Value: TSingleList);
begin
  FdMomentsOfInertia.Send(Value);
end;

function THAnimSegmentNode.GetNameField: String;
begin
  Result := FdName.Value;
end;

procedure THAnimSegmentNode.SetNameField(const Value: String);
begin
  FdName.Send(Value);
end;

function THAnimSegmentNode.GetRotation: TVector4;
begin
  Result := FdRotation.Value;
end;

procedure THAnimSegmentNode.SetRotation(const Value: TVector4);
begin
  FdRotation.Send(Value);
end;

function THAnimSegmentNode.GetScale: TVector3;
begin
  Result := FdScale.Value;
end;

procedure THAnimSegmentNode.SetScale(const Value: TVector3);
begin
  FdScale.Send(Value);
end;

function THAnimSegmentNode.GetTranslation: TVector3;
begin
  Result := FdTranslation.Value;
end;

procedure THAnimSegmentNode.SetTranslation(const Value: TVector3);
begin
  FdTranslation.Send(Value);
end;

{$endif read_implementation}
