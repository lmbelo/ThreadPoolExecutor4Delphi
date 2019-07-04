{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Collections;

interface

uses
  Classes, Contnrs;

type  
  TCustomQueue = class
  private
    function GetList: TList; type
    TQueueEx = class(Contnrs.TQueue)
    private
      function GetList: TList;
    public
      property List: TList read GetList;
    end;
  private
    FSysQueue: TQueueEx;
  protected
    procedure PushItem(const AItem); virtual;
    procedure PopItem(var AItem); virtual;
    procedure PeekItem(var AItem); virtual;
    function RemoveItem(const AItem): boolean; virtual;
  public
    constructor Create();
    destructor Destroy(); override;
    
    procedure Push(const AItem);
    procedure Pop(var AItem);
    procedure Peek(var AItem);
    function Remove(const AItem): boolean;

    function Count: Integer;
    function AtLeast(ACount: Integer): Boolean;

    property List: TList read GetList;
  end;

  TDataQueue = class(TCustomQueue)
  public type TDataType = (dtPointer, dtObject, dtInterface);
  private
    FDataType: TDataType;
  protected
    procedure PushItem(const AItem); override;
    procedure PopItem(var AItem); override;
    procedure PeekItem(var AItem); override;
    function RemoveItem(const AItem): boolean; override;
  public
    constructor Create(const ADataType: TDataType); virtual;
    
    property DataType: TDataType read FDataType;
  end;

implementation

{ TQueue }

function TCustomQueue.AtLeast(ACount: Integer): Boolean;
begin
  Result := FSysQueue.AtLeast(ACount);
end;

function TCustomQueue.Count: Integer;
begin
  Result := FSysQueue.Count;
end;

constructor TCustomQueue.Create;
begin
  FSysQueue := TQueueEx.Create();
end;

destructor TCustomQueue.Destroy;
begin
  FSysQueue.Free();
  inherited;
end;

function TCustomQueue.GetList: TList;
begin
  Result := FSysQueue.List;
end;

procedure TCustomQueue.PeekItem(var AItem);
begin
  Pointer(AItem) := FSysQueue.Peek;
end;

procedure TCustomQueue.PopItem(var AItem);
begin
  Pointer(AItem) := FSysQueue.Pop;
end;

procedure TCustomQueue.PushItem(const AItem);
begin
  FSysQueue.PushItem(Pointer(AItem));
end;

function TCustomQueue.RemoveItem(const AItem): boolean;
begin
  Result := FSysQueue.List.Remove(Pointer(AItem)) > -1;
end;

procedure TCustomQueue.Push(const AItem);
begin
  PushItem(AItem);
end;

procedure TCustomQueue.Peek(var AItem);
begin
  PeekItem(AItem);
end;

procedure TCustomQueue.Pop(var AItem);
begin
  PopItem(AItem);
end;

function TCustomQueue.Remove(const AItem): boolean;
begin
  Result := RemoveItem(AItem);
end;      

{ TQueue.TQueueEx }

function TCustomQueue.TQueueEx.GetList: TList;
begin
  Result := inherited List;
end;

{ TInterfaceQueue }

constructor TDataQueue.Create(const ADataType: TDataType);
begin
  inherited Create;
  FDataType := ADataType;
end;

procedure TDataQueue.PeekItem(var AItem);
var
  LItem: Pointer;
begin
  LItem := nil;
  inherited PeekItem(LItem);
  if Assigned(LItem) then begin
    if FDataType = dtInterface then begin
      IInterface(AItem) := IInterface(LItem);
    end else if FDataType = dtObject then begin
      TObject(AItem) := TObject(LItem);
    end else if FDataType = dtPointer then begin
      Pointer(AItem) := Pointer(LItem);
    end;
  end;
end;

procedure TDataQueue.PopItem(var AItem);
var
  LItem: pointer;
begin
  LItem := nil;
  inherited PopItem(LItem);
  if Assigned(LItem) then begin
    if FDataType = dtInterface then begin
      IInterface(AItem) := IInterface(LItem);
      IInterface(LItem) := nil;
    end else if FDataType = dtObject then begin
      TObject(AItem) := TObject(LItem);
    end else if FDataType = dtPointer then begin
      Pointer(AItem) := Pointer(LItem);
    end;
  end;
end;

procedure TDataQueue.PushItem(const AItem);
var
  LIx: Integer;
begin
  inherited PushItem(AItem);
  if FDataType = dtInterface then begin
    LIx := FSysQueue.List.IndexOf(Pointer(AItem));
    FSysQueue.List.List[LIx] := nil;
    IInterface(FSysQueue.List.List[LIx]) := IInterface(AItem);
  end;
end;

function TDataQueue.RemoveItem(const AItem): boolean;
var
  LIx: integer;
begin
  LIx := FSysQueue.List.IndexOf(Pointer(AItem));
  Result := LIx > -1;
  if Result then begin
    if FDataType = dtInterface then begin
      IInterface(FSysQueue.List.List[LIx]) := nil;
    end;
    FSysQueue.List.Delete(LIx);
  end;
end;

end.
