{
  Copyright 2015-2018 Tomasz Wojtyś, Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Display a map created in Tiled (https://www.mapeditor.org/) (TCastleTiledMapControl class). }

{$ifdef read_interface}

type
  { Display a map created in Tiled (https://www.mapeditor.org/). }
  TCastleTiledMapControl = class(TCastleUserInterface)
  strict private
    FMap: TTiledMap;
    FURL: String;
    FObjectsVisible: Boolean;
    FOrigin: TVector2;
    FScale: Single;
    FSmoothScaling, FSmoothScalingSafeBorder: Boolean;
    procedure RenderObjects;
    procedure LoadTilesetsImages;
    { Free images created by LoadTilesetsImages. }
    procedure FreeTilesetsImages;
    { Free everything created by SetURL. }
    procedure Close;
    procedure SetURL(const Value: string);
    procedure SetOrigin(const Value: TVector2);
    procedure SetScale(const Value: Single);
    procedure SetSmoothScaling(const Value: Boolean);
    procedure SetSmoothScalingSafeBorder(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Render; override;
    function PropertySection(const PropertyName: String): TPropertySection; override;

    { Load given TMX file to memory and creates structures. }
    procedure LoadFromFile(const AURL: string); deprecated 'set URL instead of calling LoadFromFile';

    { Origin determines the map position at control's left-bottom corner.
      Increasing Origin.X moves visually the map to the left,
      increasing Origin.Y moves it down. }
    property Origin: TVector2 read FOrigin write SetOrigin;

    { Currently loaded map (from @link(URL)), if any.
      @nil if no map is loaded (when @link(URL) is empty). Read-only. }
    property Map: TTiledMap read FMap;

    { Detect tile under given position.

      The interpretation of Position depends on ScreenCoordinates:

      @unorderedList(
        @item(When ScreenCoordinates = @true,
          then Position is relative to the whole container
          (like TCastleWindowBase or TCastleControlBase).

          And it is expressed in real device coordinates,
          just like @link(TInputPressRelease.Position)
          when mouse is being clicked, or like @link(TInputMotion.Position)
          when mouse is moved.
        )

        @item(When ScreenCoordinates = @false,
          then Position is relative to this UI control.

          And it is expressed in coordinates after UI scaling.
          IOW, if the size of this control is @link(Width) = 100,
          then Position.X between 0 and 100 reflects the visible range of this control.
        )
      )

      Note that you can query the positions that are outside of this UI control,
      or even outside of the container.
      They will return correct map tiles, as if the map was rendered there.
      If you want to avoid this, you can e.g. check whether Position
      is inside the @link(RenderRect) (if it's a position in screen coordinates,
      with ScreenCoordinates = @true).

      This method returns @false if the position is outside of the map.
      Valid map tiles are from (0, 0) (lower-left) to
      (@link(TTiledMap.Width) - 1, @link(TTiledMap.Height) - 1) (upper-right). }
    function PositionToTile(const Position: TVector2; const ScreenCoordinates: Boolean;
      out TilePosition: TVector2Integer): Boolean;

    { Rectangle where the given map tile is rendered.
      Useful to render something over a TCastleTiledMapControl,
      e.g. a pawn in a game.

      In some way, this method is an inverse of the @link(PositionToTile) method.
      It converts map (tile) coordinates back into coordinates useful to display
      something.
      The ScreenCoordinates value determines the coordinate system of the resulting
      rectangle. It's meaning is similar to the ScreenCoordinates parameter
      of the @link(PositionToTile) method.

      @unorderedList(
        @item(When ScreenCoordinates = @true,
          the resulting rectangle is relative to the whole container
          (like TCastleWindowBase or TCastleControlBase).
          And is expressed in real device coordinates.

          These are the same coordinates as expressed by @link(RenderRect)
          method. You can pass the resulting rectangle straight
          to @link(DrawRectangle), or @link(TDrawableImage.Draw), or @link(TSprite.Draw),
          to draw something over this tile.
        )

        @item(When ScreenCoordinates = @false,
          the resulting rectangle is specified in local coordinates of this
          control, and is expressed in coordinates after UI scaling.

          These are the same coordinates as used by children controls (TCastleUserInterface)
          or the TCastleTiledMapControl.
          E.g. you can insert a TCastleImageControl as a child of
          TCastleTiledMapControl, and set it's position/size this way,
          to draw an image over this tile.
        )
      )

      This method works for any TilePosition, even outside of valid map positions.
      Returns TFloatRectangle.Empty is @link(Map) not loaded (@link(URL) not set).

      Some maps may use tilesets in which image size is different
      than map tile size. That is, TTiledMap.TTileset.TileWidth may be different
      than TTiledMap.TileWidth for some tilesets.
      The simpler version of this method,
      without ForceTileWidth/Height, just returns the size of the map tile looking at
      (TTiledMap.TileWidth, TTiledMap.TileHeight), since it doesn't know
      the tileset you use.

      You can pass ForceTileWidth and ForceTileHeight to set particular size.
    }
    function TileRectangle(const TilePosition: TVector2Integer;
      const ScreenCoordinates: Boolean): TFloatRectangle; overload;
    function TileRectangle(const TilePosition: TVector2Integer;
      const ScreenCoordinates: Boolean;
      const ForceTileWidth, ForceTileHeight: Single): TFloatRectangle; overload;
  published
    property ClipChildren default true;

    { URL (or just filename) of the Tiled map file (TMX). }
    property URL: String read FURL write SetURL;

    property Scale: Single read FScale write SetScale default 1;

    // TODO: not implemented yet
    // property ObjectsVisible: Boolean read FObjectsVisible write FObjectsVisible;

    { How are images scaled (because of UI scaling, because of @link(Scale)).
      @true means we use nice "bilinear" filter.
      @false means we use pixelated "nearest" filter.

      Beware that using @true, and scaling the map, requires preparing
      the tileset (atlas of tile images) in a proper way. The space
      around each tile must have at least 1-pixel margin
      filled with the same color and alpha ("color bleeding"),
      otherwise bad colors will creep in because of bilinear filtering.
      Alternatively, you can use @link(SmoothScalingSafeBorder).
    }
    property SmoothScaling: Boolean read FSmoothScaling write SetSmoothScaling
      default false;

    { In case of @link(SmoothScaling),
      prevent the color outside of rendered frame from creeping in,
      by stretching the rendered frame a bit.
      See @link(TSprite.SmoothScalingSafeBorder).

      It is better to prepare the sprite (tileset) images
      with some spacing between tiles, and color bleeding,
      instead of using this property.
      This property workarounds the fact that some sprite (tileset) images
      lack proper spacing and color bleeding, but it distorts the image
      a bit, so it's no longer pixel-perfect. }
    property SmoothScalingSafeBorder: Boolean read FSmoothScalingSafeBorder write SetSmoothScalingSafeBorder
      default false;

  {$define read_interface_class}
  {$I auto_generated_persistent_vectors/tcastletiledmapcontrol_persistent_vectors.inc}
  {$undef read_interface_class}
  end;

{$endif read_interface}

{$ifdef read_implementation}

constructor TCastleTiledMapControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ClipChildren := true;
  FObjectsVisible := false;
  FScale := 1;
  FSmoothScaling := false;
  FSmoothScalingSafeBorder := false;

  {$define read_implementation_constructor}
  {$I auto_generated_persistent_vectors/tcastletiledmapcontrol_persistent_vectors.inc}
  {$undef read_implementation_constructor}
end;

destructor TCastleTiledMapControl.Destroy;
begin
  Close;

  {$define read_implementation_destructor}
  {$I auto_generated_persistent_vectors/tcastletiledmapcontrol_persistent_vectors.inc}
  {$undef read_implementation_destructor}
  inherited;
end;

procedure TCastleTiledMapControl.RenderObjects;
var
  Lay: TTiledMap.TLayer;
begin
  { Object groups. }
  for Lay in Map.Layers do
  begin
    // if Lay is TTiledMap.TObjectGroupLayer then
    // TODO: draw TObjectGroupLayer here
    // TODO: when to draw TImageLayer?
  end;
end;

procedure TCastleTiledMapControl.LoadTilesetsImages;
var
  Tileset: TTiledMap.TTileset;
  Spr: TSprite;
begin
  if Map <> nil then
    for Tileset in Map.Tilesets do
    begin
      //todo: use transparent color (implement in TSprite?)
      if Tileset.Columns = 0 then
        Tileset.Columns := Tileset.Image.Width div Tileset.TileWidth;
      if Tileset.TileCount = 0 then
        Tileset.TileCount := (Tileset.Image.Height div Tileset.TileHeight) * Tileset.Columns;
      if (Tileset.TileCount = 0) or (Tileset.Columns = 0) then
      begin
        WriteLnWarning('Empty Tileset');
        Continue;
      end;
      Spr := TSprite.Create(
        Tileset.Image.URL, Tileset.TileCount,
        Tileset.Columns, Tileset.TileCount div Tileset.Columns,
        SmoothScaling, false);
      { Note that we use here Tileset.TileWidth/Height,
        which may difer from Map.TileWidth/Height.
        This is important in case of e.g. "perspective_walls.tmx" test
        from https://github.com/bjorn/tiled/tree/master/examples . }
      Spr.DrawingWidth := Tileset.TileWidth;
      Spr.DrawingHeight := Tileset.TileHeight;
      Spr.FrameWidth := Tileset.TileWidth;
      Spr.FrameHeight := Tileset.TileHeight;
      Spr.LeftMargin := Tileset.Margin;
      Spr.TopMargin := Tileset.Margin;
      Spr.HorizontalSpacing := Tileset.Spacing;
      Spr.VerticalSpacing := Tileset.Spacing;
      Spr.VerticalSpacingBottom := true;
      Spr.SmoothScalingSafeBorder := SmoothScalingSafeBorder;
      Tileset.RendererData := Spr;
    end;
end;

procedure TCastleTiledMapControl.FreeTilesetsImages;
var
  Tileset: TTiledMap.TTileset;
begin
  if Map <> nil then
    for Tileset in Map.Tilesets do
      FreeAndNil(Tileset.RendererData);
end;

procedure TCastleTiledMapControl.Close;
begin
  FreeTilesetsImages;
  FreeAndNil(FMap);
end;

procedure TCastleTiledMapControl.LoadFromFile(const AURL: string);
begin
  URL := AURL;
end;

procedure TCastleTiledMapControl.SetURL(const Value: string);
begin
  if FURL <> Value then
  begin
    FURL := Value;
    Close;
    if Value <> '' then
      FMap := TTiledMap.Create(Value);
    LoadTilesetsImages;
  end;
end;

procedure TCastleTiledMapControl.Render;
var
  RR: TFloatRectangle;

  { Return TSprite to render this tile,
    with sprite's Frame, HorizontalFlip, VerticalFlip, DiagonalFlip already set.
    May return @nil if nothing to render. }
  function TileSprite(const Layer: TTiledMap.TLayer; const X, Y: Integer): TSprite;
  var
    Tileset: TTiledMap.TTileset;
    Frame: Integer;
    HorizontalFlip, VerticalFlip, DiagonalFlip: Boolean;
  begin
    Result := nil;

    if Map.TileRenderData(Vector2Integer(X, Y), Layer,
      Tileset, Frame, HorizontalFlip, VerticalFlip, DiagonalFlip) then
    begin
      Result := Tileset.RendererData as TSprite;
      if Result = nil then Exit;

      Result.Frame := Frame;
      Result.HorizontalFlip := HorizontalFlip;
      Result.VerticalFlip := VerticalFlip;
      // TODO: test flipping diagonally
      Result.DiagonalFlip := DiagonalFlip;
    end;
  end;

  procedure RenderTile(const Layer: TTiledMap.TLayer; const X, Y: Integer);
  var
    Spr: TSprite;
    SpriteRenderRect: TFloatRectangle;
  begin
    Spr := TileSprite(Layer, X, Y);
    if Spr = nil then Exit;

    // TODO: use Layer opacity
    // TODO: use Layer offset

    SpriteRenderRect := TileRectangle(Vector2Integer(X, Y), true,
      Spr.DrawingWidth, // corresponds to Tileset.TileWidth
      Spr.DrawingHeight // corresponds to Tileset.TileHeight
    );
    Spr.Draw(SpriteRenderRect);
  end;

var
  X, Y: Integer;
  Layer: TTiledMap.TLayer;
begin
  inherited Render;
  if Map = nil then Exit;

  RR := RenderRect;

  if Map.BackgroundColor[3] <> 0 then
    DrawRectangle(RR, Map.BackgroundColor);

  for Layer in Map.Layers do
  begin
    if not Layer.Visible then Continue;
    if (Layer is TTiledMap.TObjectGroupLayer) or
       (Layer is TTiledMap.TImageLayer) then
      Continue;

    // TODO: use Map.RenderOrder

    for Y := Map.Height - 1 downto 0 do
      for X := 0 to Map.Width - 1 do
        RenderTile(Layer, X, Y);
  end;

  if FObjectsVisible then RenderObjects;
end;

procedure TCastleTiledMapControl.SetOrigin(const Value: TVector2);
begin
  if not TVector2.PerfectlyEquals(FOrigin, Value) then
  begin
    FOrigin := Value;
    VisibleChange([chRectangle]);
  end;
end;

procedure TCastleTiledMapControl.SetScale(const Value: Single);
begin
  if FScale <> Value then
  begin
    FScale := Value;
    VisibleChange([chRectangle]);
  end;
end;

procedure TCastleTiledMapControl.SetSmoothScaling(const Value: Boolean);

  procedure ChangeExistingImages;
  var
    Tileset: TTiledMap.TTileset;
  begin
    if Map <> nil then
      for Tileset in Map.Tilesets do
        if Tileset.RendererData <> nil then
          (Tileset.RendererData as TSprite).SmoothScaling := SmoothScaling;
  end;

begin
  if FSmoothScaling <> Value then
  begin
    FSmoothScaling := Value;
    ChangeExistingImages;
    VisibleChange([chRectangle]);
  end;
end;

procedure TCastleTiledMapControl.SetSmoothScalingSafeBorder(const Value: Boolean);

  procedure ChangeExistingImages;
  var
    Tileset: TTiledMap.TTileset;
  begin
    if Map <> nil then
      for Tileset in Map.Tilesets do
        if Tileset.RendererData <> nil then
          (Tileset.RendererData as TSprite).SmoothScalingSafeBorder :=
            SmoothScalingSafeBorder;
  end;

begin
  if FSmoothScalingSafeBorder <> Value then
  begin
    FSmoothScalingSafeBorder := Value;
    ChangeExistingImages;
    VisibleChange([chRectangle]);
  end;
end;

function TCastleTiledMapControl.PositionToTile(const Position: TVector2;
  const ScreenCoordinates: Boolean;
  out TilePosition: TVector2Integer): Boolean;
begin
  if Map = nil then Exit(false);

  if ScreenCoordinates then
  begin
    { recursive call with ScreenCoordinates = false }
    Result := PositionToTile((Position - RenderRect.LeftBottom) / UIScale,
      false, TilePosition);
  end else
  begin
    Result := Map.PositionToTile((Position / Scale) + Origin, TilePosition);
  end;
end;

function TCastleTiledMapControl.TileRectangle(const TilePosition: TVector2Integer;
  const ScreenCoordinates: Boolean): TFloatRectangle;
begin
  if Map = nil then
    Result := TFloatRectangle.Empty
  else
    Result := TileRectangle(TilePosition, ScreenCoordinates, Map.TileWidth, Map.TileHeight);
end;

function TCastleTiledMapControl.TileRectangle(const TilePosition: TVector2Integer;
  const ScreenCoordinates: Boolean;
  const ForceTileWidth, ForceTileHeight: Single): TFloatRectangle;
begin
  if Map = nil then
    Result := TFloatRectangle.Empty
  else
  begin
    Result.LeftBottom := Map.TileRenderPosition(TilePosition);
    Result.Width := ForceTileWidth;
    Result.Height := ForceTileHeight;
    Result := Result.
      // Apply Origin and Scale
      Translate(-Origin).
      ScaleAround0(Scale);
    if ScreenCoordinates then
    begin
      Result := Result.
        // Apply UIScale and RenderRect (anchors etc.)
        // to honor standard TCastleUserInterface conventions
        ScaleAround0(UIScale).
        Translate(RenderRect.LeftBottom);
    end;
  end;
end;

function TCastleTiledMapControl.PropertySection(
  const PropertyName: String): TPropertySection;
begin
  if (PropertyName = 'URL') or
     (PropertyName = 'SmoothScaling') or
     (PropertyName = 'SmoothScalingSafeBorder') then
    Result := psBasic
  else
    Result := inherited PropertySection(PropertyName);
end;

{$define read_implementation_methods}
{$I auto_generated_persistent_vectors/tcastletiledmapcontrol_persistent_vectors.inc}
{$undef read_implementation_methods}

{$endif read_implementation}
