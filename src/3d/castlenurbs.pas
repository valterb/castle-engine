{
  Copyright 2009-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Common utilities for NURBS curves and surfaces. }
unit CastleNURBS;

{$I castleconf.inc}

interface

uses SysUtils, CastleUtils, CastleVectors, CastleBoxes;

{ Calculate the tessellation (number of NURBS points generated).
  This follows X3D spec for "an implementation subdividing
  the surface into an equal number of subdivision steps".
  Give value of tessellation field, and count of controlPoints.

  Returned value is for sure > 0 (never exactly 0). }
function ActualTessellation(const Tessellation: Integer;
  const Dimension: Cardinal): Cardinal;

{ Return point on NURBS curve.

  Requires:
  @unorderedList(
    @item PointsCount > 0 (not exactly 0).
    @item Order >= 2 (X3D and VRML 97 spec require this too).
    @item Knot must have exactly PointsCount + Order items.
    @item U is between Knot.First and Knot.Last.
  )

  Weight will be used only if it has the same length as PointsCount.
  Otherwise, weight = 1.0 (that is, defining non-rational curve) will be used
  (this follows X3D spec).

  Tangent, if non-nil, will be set to the direction at given point of the
  curve, pointing from the smaller to larger knot values.
  It will be normalized. This can be directly useful to generate
  orientations by X3D NurbsOrientationInterpolator node.

  @groupBegin }
function NurbsCurvePoint(const Points: PVector3Array;
  const PointsCount: Cardinal; const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDoubleList;
  Tangent: PVector3): TVector3;
function NurbsCurvePoint(const Points: TVector3List;
  const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDoubleList;
  Tangent: PVector3): TVector3;
{ @groupEnd }

{ Return point on NURBS surface.

  Requires:
  @unorderedList(
    @item UDimension, VDimension > 0 (not exactly 0).
    @item Points.Count must match UDimension * VDimension.
    @item Order >= 2 (X3D and VRML 97 spec require this too).
    @item Each xKnot must have exactly xDimension + Order items.
  )

  Weight will be used only if it has the same length as PointsCount.
  Otherwise, weight = 1.0 (that is, defining non-rational curve) will be used
  (this follows X3D spec).

  Normal, if non-nil, will be set to the normal at given point of the
  surface. It will be normalized. You can use this to pass these normals
  to rendering. Or to generate normals for X3D NurbsSurfaceInterpolator node. }
function NurbsSurfacePoint(const Points: TVector3List;
  const UDimension, VDimension: Cardinal;
  const U, V: Single;
  const UOrder, VOrder: Cardinal;
  UKnot, VKnot, Weight: TDoubleList;
  Normal: PVector3): TVector3;

type
  EInvalidPiecewiseBezierCount = class(Exception);

  { Naming notes: what precisely is called a "uniform" knot vector seems
    to differ in literature / software.
    Blender calls nkPeriodicUniform as "Uniform",
    and nkEndpointUniform as "Endpoint".
    http://en.wiki.mcneel.com/default.aspx/McNeel/NURBSDoc.html
    calls nkEndpointUniform as "Uniform".
    "An introduction to NURBS: with historical perspective"
    (by David F. Rogers) calls nkEndpointUniform "open uniform" and
    nkPeriodicUniform "periodic uniform". }

  { Type of NURBS knot vector to generate. }
  TNurbsKnotKind = (
    { All knot values are evenly spaced, all knots are single.
      This is good for periodic curves. }
    nkPeriodicUniform,

    { Starting and ending knots have Order multiplicity, rest is evenly spaced.
      The curve hits endpoints. }
    nkEndpointUniform,

    { NURBS curve will effectively become a piecewise Bezier curve.
      The order of NURBS curve will determine the order of Bezier curve,
      for example NURBS curve with order = 4 results in a cubic Bezier curve. }
    nkPiecewiseBezier);

{ Calculate a default knot, if Knot doesn't already have required number of items.
  After this, it's guaranteed that Knot.Count is Dimension + Order
  (just as required by NurbsCurvePoint, NurbsSurfacePoint).
  @raises(EInvalidPiecewiseBezierCount When you use nkPiecewiseBezier
    with invalid control points count (Dimension) and Order.) }
procedure NurbsKnotIfNeeded(Knot: TDoubleList;
  const Dimension, Order: Cardinal; const Kind: TNurbsKnotKind);

function NurbsBoundingBox(Point: TVector3List;
  Weight: TDoubleList): TBox3D; overload;
function NurbsBoundingBox(Point: TVector3List;
  Weight: TSingleList): TBox3D; overload;

function NurbsBoundingBox(Point: TVector3List;
  Weight: TDoubleList; const Transform: TMatrix4): TBox3D; overload;
function NurbsBoundingBox(Point: TVector3List;
  Weight: TSingleList; const Transform: TMatrix4): TBox3D; overload;

implementation

uses Math;

function ActualTessellation(const Tessellation: Integer;
  const Dimension: Cardinal): Cardinal;
begin
  if Tessellation > 0 then
    Result := Tessellation else
  if Tessellation = 0 then
    Result := 2 * Dimension else
    Result := Cardinal(-Tessellation) * Dimension;
  Inc(Result);
end;

function NurbsCurvePoint(const Points: TVector3List;
  const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDoubleList;
  Tangent: PVector3): TVector3;
begin
  Result := NurbsCurvePoint(PVector3Array(Points.List), Points.Count,
    U, Order, Knot, Weight, Tangent);
end;

function NurbsCurvePoint(const Points: PVector3Array;
  const PointsCount: Cardinal; const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDoubleList;
  Tangent: PVector3): TVector3;

  { In which knot internal is the given point. }
  function FindKnotSpan(const U: Double;
    const ControlPointCount: Integer;
    const Knot: TDoubleList): Integer;
  var
    Low, High: Integer;
  begin
    if U >= Knot.Last then
      Result := ControlPointCount - 1
    else
    begin
      Low := Order - 2;
      High := ControlPointCount - 1;
      Result := (Low + High) div 2;
      while (U < Knot[Result]) or (U > Knot[Result + 1]) do
      begin
        if U < Knot[Result] then
          High := Result
        else
          Low := Result;

        if High - Low <= 1 then
        begin
          if U < Knot[High] then
            Result := Low
          else
            Result := High;
          Break;
        end else
        begin
          Assert(Result <> (Low + High) div 2, 'FindKnotSpan would enter infinite loop');
          Result := (Low + High) div 2;
        end;
      end;
      Assert(Between(U, Knot[Result], Knot[Result + 1]));
    end;
  end;

  { The algorithm follows the "Inverted Triangular Scheme" described in
    http://isd.ktu.lt/it2010/material/Proceedings/1_AI_7.pdf

    Terminology note: Degree (denoted "p" in the above paper)
    is our Order ‑ 1.
  }

  type
    TDoubleArray = array of Double;

  { Calculate the basis functions (N) values for U. }
  function Basis_ITS0(const KnotInterval: Integer; const Order: Cardinal;
    const U: Double): TDoubleArray;
  var
    Left, Right: TDoubleArray;
    J, R: Integer;
    Saved, Tmp: Double;
  begin
    SetLength(Result, Order);
    SetLength(Left, Order);
    SetLength(Right, Order);
    Result[0] := 1;
    // Note that Left[0] and Right[0] are never accessed, their values don't matter
    for J := 1 to Order - 1 do
    begin
      Saved := 0;
      Left[J] := U - Knot[KnotInterval + 1 - J];
      Right[J] := Knot[KnotInterval + J] - U;

      { Note that our Knots are not normalized now (not in 0..1 range),
        we could fix it here by doing

          Left[J] := MapRange01(U - Knot[KnotInterval + 1 - J], Knot.First, Knot.Last);
          Right[J] := MapRange01(Knot[KnotInterval + J] - U, Knot.First, Knot.Last);

        but it doesn't seem necessary. }

      for R := 0 to J - 1 do
      begin
        Assert(not IsZero(Right[R + 1] + Left[J - R]));
        Tmp := Result[R] / (Right[R + 1] + Left[J - R]);
        Result[R] := Saved + Right[R + 1] * Tmp;
        Saved := Left[J - R] * Tmp;
      end;
      Result[J] := Saved;
    end;
  end;

  function GetPoint0(const N: TDoubleArray; const KnotInterval: Integer): TVector3;
  var
    NSum: Double;
    I, Index: Integer;
  begin
    NSum := 0;
    Result := TVector3.Zero;

    if Weight.Count <> PointsCount then
    begin
      { Optimized version in case all weights = 1.
        In this case, NSum would always be 1, so we can avoid calculating it completely. }
      for I := 0 to Order - 1 do
      begin
        Index := KnotInterval - (Order - 1) + I;
        Result := Result + N[I] * Points^[Index];
      end;
    end else
    begin
      for I := 0 to Order - 1 do
      begin
        Index := KnotInterval - (Order - 1) + I;
        NSum := NSum + N[I] * Weight.List^[Index];
        { Note that Points are already "pre-multiplied" by weights,
          see https://castle-engine.io/x3d_implementation_nurbs.php#section_homogeneous_coordinates }
        Result := Result + N[I] * Points^[Index];
      end;
      Assert(not IsZero(NSum));
      Result := Result / NSum;
    end;
  end;

var
  KnotInterval: Integer;
  N: TDoubleArray;
  TangentShift: Single;
  ShiftedResult: TVector3;
begin
  Assert(Knot.Count = PointsCount + Order);

  KnotInterval := FindKnotSpan(U, PointsCount, Knot);
  N := Basis_ITS0(KnotInterval, Order, U);
  Result := GetPoint0(N, KnotInterval);

  { calculate Tangent by simply sampling an adjacent point }
  if Tangent <> nil then
  begin
    TangentShift := (Knot.Last - Knot.First) * 0.01;
    if U < (Knot.First + Knot.Last) / 2 then
    begin
      ShiftedResult := NurbsCurvePoint(Points, PointsCount, U + TangentShift, Order, Knot, Weight, nil);
      Tangent^ := ShiftedResult - Result;
    end else
    begin
      ShiftedResult := NurbsCurvePoint(Points, PointsCount, U - TangentShift, Order, Knot, Weight, nil);
      Tangent^ := Result - ShiftedResult;
    end;
  end;
end;

function NurbsSurfacePoint(const Points: TVector3List;
  const UDimension, VDimension: Cardinal;
  const U, V: Single;
  const UOrder, VOrder: Cardinal;
  UKnot, VKnot, Weight: TDoubleList;
  Normal: PVector3): TVector3;
begin
  Result := TVector3.Zero;
  // TODO
end;

procedure NurbsKnotIfNeeded(Knot: TDoubleList;
  const Dimension, Order: Cardinal; const Kind: TNurbsKnotKind);
var
  I, Segments: Integer;
begin
  if Cardinal(Knot.Count) <> Dimension + Order then
  begin
    Knot.Count := Dimension + Order;

    case Kind of
      nkPeriodicUniform:
        begin
          for I := 0 to Knot.Count - 1 do
            Knot.List^[I] := I;
        end;
      nkEndpointUniform:
        begin
          for I := 0 to Order - 1 do
          begin
            Knot.List^[I] := 0;
            Knot.List^[Cardinal(I) + Dimension] := Dimension - Order + 1;
          end;
          for I := Order to Dimension - 1 do
            Knot.List^[I] := I - Order + 1;
          for I := 0 to Dimension + Order - 1 do
            Knot.List^[I] := Knot.List^[I] / (Dimension - Order + 1);
        end;
      nkPiecewiseBezier:
        begin
          { For useful notes on knots, see
            http://www-evasion.imag.fr/~Francois.Faure/doc/inventorMentor/sgi_html/ch08.html
            http://saccade.com/writing/graphics/KnotVectors.pdf

            For Order = 4 (cubic Bezier curve) and 3 segments you want to get
            14 knot values:
              0 0 0 0
                1 1 1
                2 2 2
              3 3 3 3

            Control points count (Dimension) must be "Segments * (Order - 1)  + 1".
            In the example above, we have Dimension = 10,
            and it matches knot count that has Dimension + Order = 14.
          }

          Segments := (Dimension - 1) div (Order - 1);
          if (Dimension - 1) mod (Order - 1) <> 0 then
            raise EInvalidPiecewiseBezierCount.CreateFmt('Invalid NURBS curve control points count (%d) for a piecewise Bezier curve with order %d',
              [Dimension, Order]);

          for I := 0 to Order - 1 do
          begin
            Knot.List^[I] := 0;
            Knot.List^[Cardinal(I) + Dimension] := Segments;
          end;
          for I := Order to Dimension - 1 do
            Knot.List^[I] := (I - Order) div (Order - 1) + 1;
        end;
      else raise EInternalError.Create('NurbsKnotIfNeeded 594');
    end;

    // Debug:
    // Writeln('Recalculated NURBS knot:');
    // for I := 0 to Knot.Count - 1 do
    //   Writeln(I:4, ' = ', Knot[I]:1:2);
  end;
end;

function NurbsBoundingBox(Point: TVector3List;
  Weight: TDoubleList): TBox3D;
var
  V: PVector3;
  W: Single;
  I: Integer;
begin
  if Weight.Count = Point.Count then
  begin
    if Point.Count = 0 then
      Result := TBox3D.Empty else
    begin
      W := Weight.List^[0];
      if W = 0 then W := 1;

      Result.Data[0] := Point.List^[0] / W;
      Result.Data[1] := Result.Data[0];

      for I := 1 to Point.Count - 1 do
      begin
        V := Point.Ptr(I);
        W := Weight.List^[I];
        if W = 0 then W := 1;

        MinVar(Result.Data[0].Data[0], V^.Data[0] / W);
        MinVar(Result.Data[0].Data[1], V^.Data[1] / W);
        MinVar(Result.Data[0].Data[2], V^.Data[2] / W);

        MaxVar(Result.Data[1].Data[0], V^.Data[0] / W);
        MaxVar(Result.Data[1].Data[1], V^.Data[1] / W);
        MaxVar(Result.Data[1].Data[2], V^.Data[2] / W);
      end;
    end;
  end else
  { Otherwise, all the weights are assumed 1.0 }
    Result := CalculateBoundingBox(Point);
end;

function NurbsBoundingBox(Point: TVector3List;
  Weight: TSingleList): TBox3D;
var
  WeightDouble: TDoubleList;
begin
  { Direct implementation using single would be much faster...
    But not important, this is only for old VRML 2.0, not for X3D. }
  WeightDouble := Weight.ToDouble;
  try
    Result := NurbsBoundingBox(Point, WeightDouble);
  finally FreeAndNil(WeightDouble) end;
end;

function NurbsBoundingBox(Point: TVector3List;
  Weight: TDoubleList; const Transform: TMatrix4): TBox3D;
var
  V: TVector3;
  W: Single;
  I: Integer;
begin
  if Weight.Count = Point.Count then
  begin
    if Point.Count = 0 then
      Result := TBox3D.Empty else
    begin
      W := Weight.List^[0];
      if W = 0 then W := 1;

      Result.Data[0] := Transform.MultPoint(Point.List^[0] / W);
      Result.Data[1] := Result.Data[0];

      for I := 1 to Point.Count - 1 do
      begin
        W := Weight.List^[I];
        if W = 0 then W := 1;

        V := Transform.MultPoint(Point.List^[I] / W);

        MinVar(Result.Data[0].Data[0], V[0]);
        MinVar(Result.Data[0].Data[1], V[1]);
        MinVar(Result.Data[0].Data[2], V[2]);

        MaxVar(Result.Data[1].Data[0], V[0]);
        MaxVar(Result.Data[1].Data[1], V[1]);
        MaxVar(Result.Data[1].Data[2], V[2]);
      end;
    end;
  end else
  { Otherwise, all the weights are assumed 1.0 }
    Result := CalculateBoundingBox(Point, Transform);
end;

function NurbsBoundingBox(Point: TVector3List;
  Weight: TSingleList; const Transform: TMatrix4): TBox3D;
var
  WeightDouble: TDoubleList;
begin
  { Direct implementation using single would be much faster...
    But not important, this is only for old VRML 2.0, not for X3D. }
  WeightDouble := Weight.ToDouble;
  try
    Result := NurbsBoundingBox(Point, WeightDouble, Transform);
  finally FreeAndNil(WeightDouble) end;
end;

end.
