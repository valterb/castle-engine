{
  Copyright 2009-2013 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ User interface (2D) basic classes. }
unit CastleUIControls;

interface

uses SysUtils, Classes, CastleKeysMouse, CastleUtils, CastleClassUtils,
  CastleGenericLists, CastleRectangles;

const
  { Default value for container's Dpi, as it usually set on desktops. }
  DefaultDpi = 96;

type
  { Basic user interface container. This may be a window
    (like TCastleWindowCustom) or some Lazarus control (like TCastleControlCustom
    component). }
  IUIContainer = interface
  ['{0F0BA87D-95C3-4520-B9F9-CDF30015FDB3}']
    procedure SetMousePosition(const NewMouseX, NewMouseY: Integer);

    function GetMouseX: Integer;
    function GetMouseY: Integer;

    property MouseX: Integer read GetMouseX;
    property MouseY: Integer read GetMouseY;

    function GetWidth: Integer;
    function GetHeight: Integer;

    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    function Rect: TRectangle;

    function GetDpi: Integer;
    property Dpi: Integer read GetDpi;

    function GetMousePressed: TMouseButtons;
    function GetPressed: TKeysPressed;

    { Mouse buttons currently pressed. }
    property MousePressed: TMouseButtons read GetMousePressed;

    { Keys currently pressed. }
    property Pressed: TKeysPressed read GetPressed;

    function GetTooltipX: Integer;
    function GetTooltipY: Integer;

    property TooltipX: Integer read GetTooltipX;
    property TooltipY: Integer read GetTooltipY;

    { Called by controls within this container when something could
      change the container focused control (or it's cursor).
      In practice, called when TUIControl.Cursor or TUIControl.PositionInside
      results change. This is called by a IUIContainer interface, that's why
      it can remain as private method of actual container class.

      This recalculates the focused control and the final cursor of
      the container, looking at Container's UseControls,
      testing PositionInside with current mouse position,
      and looking at Cursor property of the focused control.

      When UseControls change, or when you add / remove some control
      from the Controls list, or when you move mouse (focused changes)
      this will also be automatically called
      (since focused control or final container cursor may also change then). }
    procedure UpdateFocusAndMouseCursor;
  end;

  { In what projection TUIControl.Draw will be called.
    See TUIControl.Draw, TUIControl.DrawStyle. }
  TUIControlDrawStyle = (dsNone, ds2D, ds3D);

  { Base class for things that listen to user input: cameras and 2D controls. }
  TInputListener = class(TComponent)
  private
    FOnVisibleChange: TNotifyEvent;
    FContainerWidth, FContainerHeight: Cardinal;
    FContainerRect: TRectangle;
    FContainerSizeKnown: boolean;
    FContainer: IUIContainer;
    FCursor: TMouseCursor;
    FOnCursorChange: TNotifyEvent;
    FExclusiveEvents: boolean;
    procedure SetCursor(const Value: TMouseCursor);
  protected
    { Container (window containing the control) size, as known by this control,
      undefined when ContainerSizeKnown = @false. This is simply collected at
      ContainerResize calls here.
      @groupBegin }
    property ContainerWidth: Cardinal read FContainerWidth;
    property ContainerHeight: Cardinal read FContainerHeight;
    property ContainerRect: TRectangle read FContainerRect;
    property ContainerSizeKnown: boolean read FContainerSizeKnown;
    { @groupEnd }
    procedure SetContainer(const Value: IUIContainer); virtual;
    { Called when @link(Cursor) changed.
      In TUIControl class, just calls OnCursorChange. }
    procedure DoCursorChange; virtual;
  public
    constructor Create(AOwner: TComponent); override;

    (*Handle press or release of a key, mouse button or mouse wheel.
      Return @true if the event was somehow handled.

      In this class this always returns @false, when implementing
      in descendants you should override it like

      @longCode(#
  Result := inherited;
  if Result or (not GetExists) then Exit;
  { ... And do the job here.
    In other words, the handling of events in inherited
    class should have a priority. }
#)

      Note that releasing of mouse wheel is not implemented for now,
      neither by CastleWindow or Lazarus CastleControl.
      @groupBegin *)
    function Press(const Event: TInputPressRelease): boolean; virtual;
    function Release(const Event: TInputPressRelease): boolean; virtual;
    { @groupEnd }

    function MouseMove(const OldX, OldY, NewX, NewY: Integer): boolean; virtual;

    { Rotation detected by sensor.
      Used for example by 3Dconnexion devices or touch controls.

      @param X   X axis (tilt forward/backwards)
      @param Y   Y axis (rotate)
      @param Z   Z axis (tilt sidewards)
      @param Angle   Angle of rotation
      @param(SecondsPassed The time passed since last SensorRotation call.
        This is necessary because some sensors, e.g. 3Dconnexion,
        may *not* reported as often as normal @link(Update) calls.) }
    function SensorRotation(const X, Y, Z, Angle: Double; const SecondsPassed: Single): boolean; virtual;

    { Translation detected by sensor.
      Used for example by 3Dconnexion devices or touch controls.

      @param X   X axis (move left/right)
      @param Y   Y axis (move up/down)
      @param Z   Z axis (move forward/backwards)
      @param Length   Length of the vector consisting of the above
      @param(SecondsPassed The time passed since last SensorRotation call.
        This is necessary because some sensors, e.g. 3Dconnexion,
        may *not* reported as often as normal @link(Update) calls.) }
    function SensorTranslation(const X, Y, Z, Length: Double; const SecondsPassed: Single): boolean; virtual;

    { Control may do here anything that must be continously repeated.
      E.g. camera handles here falling down due to gravity,
      rotating model in Examine mode, and many more.

      @param(SecondsPassed Should be calculated like TFramesPerSecond.UpdateSecondsPassed,
        and usually it's in fact just taken from TCastleWindowBase.Fps.UpdateSecondsPassed.)

      This method may be used, among many other things, to continously
      react to the fact that user pressed some key (or mouse button).
      For example, if holding some key should move some 3D object,
      you should do something like:

@longCode(#
if HandleInput then
begin
  if Container.Pressed[K_Right] then
    Transform.Position += Vector3Single(SecondsPassed * 10, 0, 0);
  HandleInput := not ExclusiveEvents;
end;
#)

      Instead of directly using a key code, consider also
      using TInputShortcut that makes the input key nicely configurable.
      See engine tutorial about handling inputs.

      Multiplying movement by SecondsPassed makes your
      operation frame-rate independent. Object will move by 10
      units in a second, regardless of how many FPS your game has.

      The code related to HandleInput is important if you write
      a generally-useful control that should nicely cooperate with all other
      controls, even when placed on top of them or under them.
      The correct approach is to only look at pressed keys/mouse buttons
      if HandleInput is @true. Moreover, if you did check
      that HandleInput is @true, and you did actually handle some keys,
      then you have to set @code(HandleInput := not ExclusiveEvents).
      As ExclusiveEvents is @true in normal circumstances,
      this will prevent the other controls (behind the current control)
      from handling the keys (they will get HandleInput = @false).
      And this is important to avoid doubly-processing the same key press,
      e.g. if two controls react to the same key, only the one on top should
      process it.

      Note that to handle a single press / release (like "switch
      light on when pressing a key") you should rather
      use @link(Press) and @link(Release) methods. Use this method
      only for continous handling (like "holding this key makes
      the light brighter and brighter").

      To understand why such HandleInput approach is needed,
      realize that the "Update" events are called
      differently than simple mouse and key events like "Press" and "Release".
      "Press" and "Release" events
      return whether the event was somehow "handled", and the container
      passes them only to the controls under the mouse (decided by
      PositionInside). And as soon as some control says it "handled"
      the event, other controls (even if under the mouse) will not
      receive the event.

      This approach is not suitable for Update events. Some controls
      need to do the Update job all the time,
      regardless of whether the control is under the mouse and regardless
      of what other controls already did. So all controls receive
      Update calls.

      So the "handled" status is passed through HandleInput.
      If a control is not under the mouse, it will receive HandleInput
      = @false. If a control is under the mouse, it will receive HandleInput
      = @true as long as no other control on top of it didn't already
      change it to @false. }
    procedure Update(const SecondsPassed: Single;
      var HandleInput: boolean); virtual;

    { Called always when some visible part of this control
      changes. In the simplest case, this is used by the controls manager to
      know when we need to redraw the control.

      In this class this simply calls OnVisibleChange (if assigned). }
    procedure VisibleChange; virtual;

    { Called always when some visible part of this control
      changes. In the simplest case, this is used by the controls manager to
      know when we need to redraw the control.

      Be careful when handling this event, various changes may cause this,
      so be prepared to handle OnVisibleChange at every time.

      @seealso VisibleChange }
    property OnVisibleChange: TNotifyEvent
      read FOnVisibleChange write FOnVisibleChange;

    { Allow window containing this control to suspend waiting for user input.
      Typically you want to override this to return @false when you do
      something in the overridden @link(Update) method.

      In this class, this simply returns always @true.

      @seeAlso TCastleWindowBase.AllowSuspendForInput }
    function AllowSuspendForInput: boolean; virtual;

    { Called always when the container (component or window with OpenGL context)
      size changes. Called only when the OpenGL context of the container
      is initialized, so you can be sure that this is called only between
      GLContextOpen and GLContextClose.

      We also make sure to call this once when inserting into
      the container controls list
      (like @link(TCastleWindowCustom.Controls) or
      @link(TCastleControlCustom.Controls)), if inserting into the container
      with already initialized OpenGL context. If inserting into the container
      without OpenGL context initialized, it will be called later,
      when OpenGL context will get initialized, right after GLContextOpen.

      In other words, this is always called to let the control know
      the size of the container, if and only if the OpenGL context is
      initialized.

      In this class, this sets values of ContainerWidth, ContainerHeight,
      ContainerRect, ContainerSizeKnown properties. }
    procedure ContainerResize(const AContainerWidth, AContainerHeight: Cardinal); virtual;

    { Container of this control. When adding control to container's Controls
      list (like TCastleWindowCustom.Controls) container will automatically
      set itself here, an when removing from container this will be changed
      back to @nil.

      May be @nil if this control is not yet inserted into any container. }
    property Container: IUIContainer read FContainer write SetContainer;

    { Mouse cursor over this control.
      When user moves mouse over the Container, the currently focused
      (topmost under the cursor) control determines the mouse cursor look. }
    property Cursor: TMouseCursor read FCursor write SetCursor default mcDefault;

    { Event called when the @link(Cursor) property changes.
      This event is, in normal circumstances, used by the Container,
      so you should not use it in your own programs. }
    property OnCursorChange: TNotifyEvent
      read FOnCursorChange write FOnCursorChange;

    { Design note: ExclusiveEvents is not published now, as it's too "obscure"
      (for normal usage you don't want to deal with it). Also, it's confusing
      on TCastleSceneCore, the name suggests it relates to ProcessEvents (VRML events,
      totally not related to this property that is concerned with handling
      TUIControl events.) }

    { Should we disable further mouse / keys handling for events that
      we already handled in this control. If @true, then our events will
      return @true for mouse and key events handled.

      This means that events will not be simultaneously handled by both this
      control and some other (or camera or normal window callbacks),
      which is usually more sensible, but sometimes somewhat limiting. }
    property ExclusiveEvents: boolean
      read FExclusiveEvents write FExclusiveEvents default true;
  end;

  { Basic user interface control class. All controls derive from this class,
    overriding chosen methods to react to some events.
    Various user interface containers (things that directly receive messages
    from something outside, like operating system, windowing library etc.)
    implement support for such controls.

    Control may handle mouse/keyboard input, see Press and Release
    methods.

    Various methods return boolean saying if input event is handled.
    The idea is that not handled events are passed to the next
    control suitable. Handled events are generally not processed more
    --- otherwise the same event could be handled by more than one listener,
    which is bad. Generally, return ExclusiveEvents if anything (possibly)
    was done (you changed any field value etc.) as a result of this,
    and only return @false when you're absolutely sure that nothing was done
    by this control.

    All screen (mouse etc.) coordinates passed here should be in the usual
    window system coordinates, that is (0, 0) is left-top window corner.
    (Note that this is contrary to the usual OpenGL 2D system,
    where (0, 0) is left-bottom window corner.) }
  TUIControl = class(TInputListener)
  private
    FDisableContextOpenClose: Cardinal;
    FFocused: boolean;
    FGLInitialized: boolean;
    FExists: boolean;
    procedure SetExists(const Value: boolean);
  protected
    { Return whether item really exists, see @link(Exists).
      It TUIControl class, returns @link(Exists) value.
      May be modified in subclasses, to return something more complicated. }
    function GetExists: boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Is given position inside this control.
      Returns always @false in this class. }
    function PositionInside(const X, Y: Integer): boolean; virtual;

    { Prepare your resources, right before drawing. }
    procedure BeforeDraw; virtual;

    { Draw a control. If you want your Draw called automatically by the
      window, return something <> dsNone from DrawStyle,
      and draw your control inside Draw.

      Do's and don't's when implementing Draw:

      @unorderedList(
        @item(All controls with DrawStyle = ds3D are drawn first.

          The state of projection matrix (GL_PROJECTION for fixed-function
          pipeline, and global ProjectionMatrix variable) is undefined for
          ds3D objects. As is the viewport.
          So you should always set the viewport and projection yourself
          at the beginning of ds3D rendring, usually by
          CastleGLUtils.PerspectiveProjection or CastleGLUtils.OrthoProjection.
          Usually you should just use TCastleSceneManager,
          which automatically sets projection to something suitable,
          see TCastleSceneManager.ApplyProjection and TCastleScene.GLProjection.

          Then all the controls with DrawStyle = ds2D are drawn.
          For them, OpenGL projection is guaranteed to be set
          to standard 2D that fills the whole screen, like by

@longCode(#
  glViewport(0, Container.Width, 0, Container.Height);
  OrthoProjection(0, Container.Width, 0, Container.Height);
#)
        )

        @item(The only OpenGL state you can change carelessly is:
          @unorderedList(
            @itemSpacing Compact
            @item The modelview matrix value.
            @item ds3D controls can also freely change projection matrix value and viewport.
            @item(The raster position and WindowPos. The only place in our engine
              using WindowPos is the deprecated TCastleFont methods (ones without
              explicit X, Y).)
            @item The color (glColor), material (glMaterial) values.
            @item The line width, point size.
          )
          Every other change should be secured to go back to original value.
          For older OpenGL, you can use glPushAttrib / glPopAttrib.
          For things that have guaranteed values at the beginning of draw method
          (e.g. scissor is always off for ds2D controls),
          you can also just manually set it back to off at the end
          (e.g. if you use scissor, them remember to disable it back
          at the end of draw method.)
        )

        @item(Things that are guaranteed about OpenGL state when Draw is called:
          @unorderedList(
            @itemSpacing Compact
            @item The current matrix is modelview, and it's value is identity.
            @item(Only for DrawStyle = ds2D: the WindowPos is at (0, 0).
              The projection and viewport is suitable as for 2D, see above.)
            @item(Only for DrawStyle = ds2D: Texturing, depth test,
              lighting, fog, scissor are turned off.)
          )
          If you require anything else, set this yourself.)
      )

      When @link(GetExists) is @false, remember to do nothing in Draw,
      and return dsNone in DrawStyle.

      @groupBegin }
    procedure Draw; virtual;
    function DrawStyle: TUIControlDrawStyle; virtual;
    { @groupEnd }

    { Draw a tooltip of this control. If you want to have tooltip for
      this control detected, you have to override TooltipStyle
      to return something <> dsNone.
      Then the TCastleWindowBase.TooltipVisible will be detected,
      and your DrawTooltip will be called.

      So you can draw your tooltip either in overridden DrawTooltip,
      and/or somewhere else when you see that TCastleWindowBase.TooltipVisible is @true.
      (Tooltip is always drawn for TCastleWindowBase.Focus control.)
      But in both cases, make sure to override TooltipStyle to return
      something <> dsNone.

      The values of ds2D and ds3D are interpreted in the same way
      as DrawStyle. And DrawTooltip is called in the same way as @link(Draw),
      so e.g. you can safely assume that modelview matrix is identity
      and (for 2D) WindowPos is zero.
      DrawTooltip is always called as a last (front-most) 2D or 3D control.

      @groupBegin }
    function TooltipStyle: TUIControlDrawStyle; virtual;
    procedure DrawTooltip; virtual;
    { @groupEnd }

    { Initialize your OpenGL resources.

      This is called when OpenGL context of the container is created.
      Also called when the control is added to the already existing context.
      In other words, this is the moment when you can initialize
      OpenGL resources, like display lists, VBOs, OpenGL texture names, etc. }
    procedure GLContextOpen; virtual;

    { Destroy your OpenGL resources.

      Called when OpenGL context of the container is destroyed.
      Also called when controls is removed from the container
      @code(Controls) list. Also called from the destructor.

      You should release here any resources that are tied to the
      OpenGL context. In particular, the ones created in GLContextOpen. }
    procedure GLContextClose; virtual;

    property GLInitialized: boolean read FGLInitialized default false;

    { When non-zero, container will not call GLContextOpen and
      GLContextClose (when control is added/removed to/from the
      @code(Controls) list).

      This is useful, although should be used with much caution:
      you're expected to call controls GLContextOpen /
      GLContextClose on your own when this is non-zero. Example usage is
      when the same control is often added/removed to/from the @code(Controls)
      list, and the window (with it's OpenGL context) stays open for a longer
      time. In such case, default (when DisableContextOpenClose = 0) behavior
      will often release (only to be forced to reinitialize again) OpenGL
      resources of the control. Some controls have large OpenGL
      resources (for example TCastleScene keeps display lists, textures etc.,
      and TCastlePrecalculatedAnimation keeps all the scenes) --- so constantly
      reinitializing them may eat a noticeable time.

      By using non-zero DisableContextOpenClose you can disable this behavior.

      In particular, TGLMode uses this trick, to avoid releasing and
      reinitializing OpenGL resources for controls only temporarily
      removed from the @link(TCastleWindowCustom.Controls) list. }
    property DisableContextOpenClose: Cardinal
      read FDisableContextOpenClose write FDisableContextOpenClose;

    { Called when this control becomes or stops being focused.
      In this class, they simply update Focused property. }
    procedure SetFocused(const Value: boolean); virtual;

    property Focused: boolean read FFocused write SetFocused;

  published
    { Not existing control is not visible, it doesn't receive input
      and generally doesn't exist from the point of view of user.
      You can also remove this from controls list (like
      @link(TCastleWindowCustom.Controls)), but often it's more comfortable
      to set this property to false. }
    property Exists: boolean read FExists write SetExists default true;
  end;

  { TUIControl that has a position and takes some rectangular space
    on the container.

    The position is controlled using the Left, Bottom fields.
    The rectangle where the control is visible can be queried using
    the @link(Rect) virtual method.

    Note that each descendant has it's own definition of the size of the control.
    E.g. some descendants may automatically calculate the size
    (based on text or images or such placed within the control).
    Some descendants may allow to control the size explicitly
    using fields like Width, Height, FullSize.
    Some descendants may allow both approaches, switchable by
    property like TCastleButton.AutoSize or TCastleImageControl.Stretch. }
  TUIRectangularControl = class(TUIControl)
  private
    FLeft: Integer;
    FBottom: Integer;

    { This takes care of some internal quirks with saving Left property
      correctly. (Because TComponent doesn't declare, but saves/loads a "magic"
      property named Left during streaming. This is used to place non-visual
      components on the form. Our Left is completely independent from this.) }
    procedure ReadRealLeft(Reader: TReader);
    procedure WriteRealLeft(Writer: TWriter);

    Procedure ReadLeft(Reader: TReader);
    Procedure ReadTop(Reader: TReader);
    Procedure WriteLeft(Writer: TWriter);
    Procedure WriteTop(Writer: TWriter);

    procedure SetLeft(const Value: Integer);
    procedure SetBottom(const Value: Integer);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    { Position and size of this control, assuming it exists.
      This must ignore the current value of the @link(GetExists) method
      and @link(Exists) property, that is: the result of this function
      assumes that control does exist. }
    function Rect: TRectangle; virtual; abstract;
    { Center the control within the container horizontally by adjusting @link(Left). }
    procedure CenterHorizontal;
    { Center the control within the container vertically by adjusting @link(Bottom). }
    procedure CenterVertical;
    { Center the control within the container both horizontally and vertically. }
    procedure Center;
  published
    property Left: Integer read FLeft write SetLeft stored false default 0;
    property Bottom: Integer read FBottom write SetBottom default 0;
  end;

  TUIControlPos = TUIRectangularControl deprecated;

  TUIControlList = class(TCastleObjectList)
  private
    type
      TEnumerator = class
      private
        FList: TUIControlList;
        FPosition: Integer;
        function GetCurrent: TUIControl;
      public
        constructor Create(AList: TUIControlList);
        function MoveNext: Boolean;
        property Current: TUIControl read GetCurrent;
      end;

    function GetItem(const I: Integer): TUIControl;
    procedure SetItem(const I: Integer; const Item: TUIControl);
  public
    property Items[I: Integer]: TUIControl read GetItem write SetItem; default;
    procedure Add(Item: TUIControl);
    procedure Insert(Index: Integer; Item: TUIControl);

    function GetEnumerator: TEnumerator;

    { Add at the beginning of the list.
      This is just a shortcut for @code(Insert(0, NewItem)),
      but makes it easy to remember that controls at the beginning of the list
      are in front (they get key/mouse events first). }
    procedure InsertFront(const NewItem: TUIControl);

    { Add at the end of the list.
      This is just another name for @code(Add(NewItem)), but makes it easy
      to remember that controls at the end of the list are at the back
      (they get key/mouse events last). }
    procedure InsertBack(const NewItem: TUIControl);

    { BeginDisableContextOpenClose disables sending
      TUIControl.GLContextOpen and TUIControl.GLContextClose to all the controls
      on the list. EndDisableContextOpenClose ends this.
      They work by increasing / decreasing the TUIControl.DisableContextOpenClose
      for all the items on the list.

      @groupBegin }
    procedure BeginDisableContextOpenClose;
    procedure EndDisableContextOpenClose;
    { @groupEnd }
  end;

  TGLContextEvent = procedure;

  TGLContextEventList = class(specialize TGenericStructList<TGLContextEvent>)
  public
    { Call all items. }
    procedure ExecuteAll;
  end;

{ Global callbacks called when OpenGL context (like Lazarus TCastleControl
  or TCastleWindow) is open/closed.
  Useful for things that want to be notified
  about OpenGL context existence, but cannot refer to a particular instance
  of TCastleControl or TCastleWindow.

  Note that we may have many OpenGL contexts (TCastleWindow or TCastleControl)
  open simultaneously. They all share OpenGL resources.
  OnGLContextOpen is called when first OpenGL context is open,
  that is: no previous context was open.
  OnGLContextClose is called when last OpenGL context is closed,
  that is: no more contexts remain open.
  Note that this implies that they may be called many times:
  e.g. if you open one window, then close it, then open another
  window then close it.

  @groupBegin }
function OnGLContextOpen: TGLContextEventList;
function OnGLContextClose: TGLContextEventList;
{ @groupEnd }

implementation

{ TInputListener ------------------------------------------------------------- }

constructor TInputListener.Create(AOwner: TComponent);
begin
  inherited;
  FExclusiveEvents := true;
  FCursor := mcDefault;
end;

function TInputListener.Press(const Event: TInputPressRelease): boolean;
begin
  Result := false;
end;

function TInputListener.Release(const Event: TInputPressRelease): boolean;
begin
  Result := false;
end;

function TInputListener.MouseMove(const OldX, OldY, NewX, NewY: Integer): boolean;
begin
  Result := false;
end;

function TInputListener.SensorRotation(const X, Y, Z, Angle: Double; const SecondsPassed: Single): boolean;
begin
  Result := false;
end;

function TInputListener.SensorTranslation(const X, Y, Z, Length: Double; const SecondsPassed: Single): boolean;
begin
  Result := false;
end;

procedure TInputListener.Update(const SecondsPassed: Single;
  var HandleInput: boolean);
begin
end;

procedure TInputListener.VisibleChange;
begin
  if Assigned(OnVisibleChange) then
    OnVisibleChange(Self);
end;

function TInputListener.AllowSuspendForInput: boolean;
begin
  Result := true;
end;

procedure TInputListener.ContainerResize(const AContainerWidth, AContainerHeight: Cardinal);
begin
  FContainerWidth := AContainerWidth;
  FContainerHeight := AContainerHeight;
  FContainerRect := Rectangle(0, 0, AContainerWidth, AContainerHeight);
  FContainerSizeKnown := true;
end;

procedure TInputListener.SetCursor(const Value: TMouseCursor);
begin
  if Value <> FCursor then
  begin
    FCursor := Value;
    if Container <> nil then Container.UpdateFocusAndMouseCursor;
    DoCursorChange;
  end;
end;

procedure TInputListener.DoCursorChange;
begin
  if Assigned(OnCursorChange) then OnCursorChange(Self);
end;

procedure TInputListener.SetContainer(const Value: IUIContainer);
begin
  FContainer := Value;
end;

{ TUIControl ----------------------------------------------------------------- }

constructor TUIControl.Create(AOwner: TComponent);
begin
  inherited;
  FExists := true;
end;

destructor TUIControl.Destroy;
begin
  GLContextClose;
  inherited;
end;

function TUIControl.PositionInside(const X, Y: Integer): boolean;
begin
  Result := false;
end;

function TUIControl.DrawStyle: TUIControlDrawStyle;
begin
  Result := dsNone;
end;

procedure TUIControl.BeforeDraw;
begin
end;

procedure TUIControl.Draw;
begin
end;

function TUIControl.TooltipStyle: TUIControlDrawStyle;
begin
  Result := dsNone;
end;

procedure TUIControl.DrawTooltip;
begin
end;

procedure TUIControl.GLContextOpen;
begin
  FGLInitialized := true;
end;

procedure TUIControl.GLContextClose;
begin
  FGLInitialized := false;
end;

function TUIControl.GetExists: boolean;
begin
  Result := FExists;
end;

procedure TUIControl.SetFocused(const Value: boolean);
begin
  FFocused := Value;
end;

procedure TUIControl.SetExists(const Value: boolean);
begin
  { Exists is typically used in PositionInside implementations,
    so changing it must case UpdateFocusAndMouseCursor. }
  if FExists <> Value then
  begin
    FExists := Value;
    if Container <> nil then Container.UpdateFocusAndMouseCursor;
  end;
end;

{ TUIRectangularControl -------------------------------------------------------------- }

{ We store Left property value in file under "tuicontrolpos_real_left" name,
  to avoid clashing with TComponent magic "left" property name.
  The idea how to do this is taken from TComponent's own implementation
  of it's "left" magic property (rtl/objpas/classes/compon.inc). }

procedure TUIRectangularControl.ReadRealLeft(Reader: TReader);
begin
  FLeft := Reader.ReadInteger;
end;

procedure TUIRectangularControl.WriteRealLeft(Writer: TWriter);
begin
  Writer.WriteInteger(FLeft);
end;

Procedure TUIRectangularControl.ReadLeft(Reader: TReader);
var
  D: LongInt;
begin
  D := DesignInfo;
  LongRec(D).Lo:=Reader.ReadInteger;
  DesignInfo := D;
end;

Procedure TUIRectangularControl.ReadTop(Reader: TReader);
var
  D: LongInt;
begin
  D := DesignInfo;
  LongRec(D).Hi:=Reader.ReadInteger;
  DesignInfo := D;
end;

Procedure TUIRectangularControl.WriteLeft(Writer: TWriter);
begin
  Writer.WriteInteger(LongRec(DesignInfo).Lo);
end;

Procedure TUIRectangularControl.WriteTop(Writer: TWriter);
begin
  Writer.WriteInteger(LongRec(DesignInfo).Hi);
end;

procedure TUIRectangularControl.DefineProperties(Filer: TFiler);
Var Ancestor : TComponent;
    Temp : longint;
begin
  { Don't call inherited that defines magic left/top.
    This would make reading design-time "left" broken, it seems that our
    declaration of Left with "stored false" would then prevent the design-time
    Left from ever loading.

    Instead, we'll save design-time "Left" below, under a special name. }

  Filer.DefineProperty('TUIControlPos_RealLeft', @ReadRealLeft, @WriteRealLeft,
    FLeft <> 0);

  { Code from fpc/trunk/rtl/objpas/classes/compon.inc }
  Temp:=0;
  Ancestor:=TComponent(Filer.Ancestor);
  If Assigned(Ancestor) then Temp:=Ancestor.DesignInfo;
  Filer.Defineproperty('TUIControlPos_Design_Left',@readleft,@writeleft,
                       (longrec(DesignInfo).Lo<>Longrec(temp).Lo));
  Filer.Defineproperty('TUIControlPos_Design_Top',@readtop,@writetop,
                       (longrec(DesignInfo).Hi<>Longrec(temp).Hi));
end;

procedure TUIRectangularControl.SetLeft(const Value: Integer);
begin
  if FLeft <> Value then
  begin
    FLeft := Value;
    if Container <> nil then Container.UpdateFocusAndMouseCursor;
  end;
end;

procedure TUIRectangularControl.SetBottom(const Value: Integer);
begin
  if FBottom <> Value then
  begin
    FBottom := Value;
    if Container <> nil then Container.UpdateFocusAndMouseCursor;
  end;
end;

procedure TUIRectangularControl.CenterHorizontal;
begin
  // cast to Integer early, as Left may be < 0
  Left := (ContainerWidth - Integer(Rect.Width)) div 2;
end;

procedure TUIRectangularControl.CenterVertical;
begin
  // cast to Integer early, as Bottom may be < 0
  Bottom := (ContainerHeight - Integer(Rect.Height)) div 2;
end;

procedure TUIRectangularControl.Center;
begin
  CenterHorizontal;
  CenterVertical;
end;

{ TUIControlList ------------------------------------------------------------- }

function TUIControlList.GetItem(const I: Integer): TUIControl;
begin
  Result := TUIControl(inherited Items[I]);
end;

procedure TUIControlList.SetItem(const I: Integer; const Item: TUIControl);
begin
  inherited Items[I] := Item;
end;

procedure TUIControlList.Add(Item: TUIControl);
begin
  inherited Add(Item);
end;

procedure TUIControlList.Insert(Index: Integer; Item: TUIControl);
begin
  inherited Insert(Index, Item);
end;

procedure TUIControlList.BeginDisableContextOpenClose;
var
  I: Integer;
begin
 for I := 0 to Count - 1 do
   with Items[I] do
     DisableContextOpenClose := DisableContextOpenClose + 1;
end;

procedure TUIControlList.EndDisableContextOpenClose;
var
  I: Integer;
begin
 for I := 0 to Count - 1 do
   with Items[I] do
     DisableContextOpenClose := DisableContextOpenClose - 1;
end;

procedure TUIControlList.InsertFront(const NewItem: TUIControl);
begin
  Insert(0, NewItem);
end;

procedure TUIControlList.InsertBack(const NewItem: TUIControl);
begin
  Add(NewItem);
end;

function TUIControlList.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

{ TUIControlList.TEnumerator ------------------------------------------------- }

function TUIControlList.TEnumerator.GetCurrent: TUIControl;
begin
  Result := FList.Items[FPosition];
end;

constructor TUIControlList.TEnumerator.Create(AList: TUIControlList);
begin
  inherited Create;
  FList := AList;
  FPosition := -1;
end;

function TUIControlList.TEnumerator.MoveNext: Boolean;
begin
  Inc(FPosition);
  Result := FPosition < FList.Count;
end;

{ TGLContextEventList -------------------------------------------------------- }

procedure TGLContextEventList.ExecuteAll;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I]();
end;

var
  FOnGLContextOpen, FOnGLContextClose: TGLContextEventList;

function OnGLContextOpen: TGLContextEventList;
begin
  if FOnGLContextOpen = nil then
    FOnGLContextOpen := TGLContextEventList.Create;
  Result := FOnGLContextOpen;
end;

function OnGLContextClose: TGLContextEventList;
begin
  if FOnGLContextClose = nil then
    FOnGLContextClose := TGLContextEventList.Create;
  Result := FOnGLContextClose;
end;

finalization
  FreeAndNil(FOnGLContextOpen);
  FreeAndNil(FOnGLContextClose);
end.
