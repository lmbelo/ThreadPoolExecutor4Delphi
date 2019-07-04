{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit BlockingQueue;

interface

uses
  SyncObjs, DateUtils, SysUtils, Classes, Collections, Exceptions;

type
  TPointerArray = array of pointer;
  TInterfaceArray = array of IInterface;
  TBlockingQueue = class(TDataQueue)
  private
    FLockQueue, FLockItem, FLockSpace: TCriticalSection;
    FCapacity: integer;
    FInterrupted: boolean;
    procedure CheckCapacity;
    procedure CheckNull(const AItem: pointer);
    procedure CheckEmpty;
    procedure WaitForSpace(); overload;
    procedure WaitForItem(); overload;
    function HasAvailableSpace(): boolean;
    function HasAvailableItem(): boolean;
    function WaitForSpace(const ATimeOut: Int64): boolean; overload;
    function WaitForItem(const ATimeOut: Int64): boolean; overload;
    procedure DoSleep(const AMilliSeconds: cardinal);
  protected
    constructor Create(const ADataType: TDataQueue.TDataType; const ACapacity: integer); reintroduce; overload; virtual;
  protected
    function Add(const AItem): boolean;
    function Remove(const AItem): boolean;
    procedure Element(var AItem);

    function Offer(const AItem): boolean; overload;
    procedure Poll(var AItem); overload;
    procedure Peek(var AItem);

    procedure Put(const AItem);
    procedure Take(var AItem);

    function Offer(const AItem; const ATimeOut: Int64): boolean; overload;
    procedure Poll(var AItem; const ATimeOut: Int64); overload;
  public
    constructor Create; reintroduce; overload;
    constructor Create(const ACapacity: integer); reintroduce; overload;
    destructor Destroy; override;

    function Count: integer;
    function IsEmpty: boolean;
    function RemainingCapacity: integer;
    function ToArray: TPointerArray;

    property Capacity: integer read FCapacity write FCapacity;
  end;

  TInterfaceBlockingQueue = class(TBlockingQueue)
  protected
    constructor Create(const ADataType: TDataQueue.TDataType; const ACapacity: integer); overload; override;
  public
    function Add(const AItem: IInterface): boolean;
    function Remove(const AItem: IInterface): boolean;
    function Element(): IInterface;

    function Offer(const AItem: IInterface): boolean; overload;
    function Poll: IInterface; overload;
    function Peek: IInterface;

    procedure Put(const AItem: IInterface);
    function Take: IInterface; 

    function Offer(const AItem: IInterface; const ATimeOut: Int64): boolean; overload;
    function Poll(const ATimeOut: Int64): IInterface; overload;

    function ToArray: TInterfaceArray;
  end;

  TObjectBlockingQueue = class(TBlockingQueue)
  protected
    constructor Create(const ADataType: TDataQueue.TDataType; const ACapacity: integer); overload; override;
  public
    function Add(const AItem: TObject): boolean;
    function Remove(const AItem: TObject): boolean;
    function Element(): TObject;

    function Offer(const AItem: TObject): boolean; overload;
    function Poll: TObject; overload;
    function Peek: TObject; overload;

    procedure Put(const AItem: TObject);
    function Take: TObject;

    function Offer(const AItem: TObject; const ATimeOut: Int64): boolean; overload;
    function Poll(const ATimeOut: Int64): TObject; overload;

    function ToArray: TPointerArray;
  end;

implementation

uses
  Windows, TypInfo, Threading;

{ TBlockingQueue }

constructor TBlockingQueue.Create(const ADataType: TDataQueue.TDataType;
  const ACapacity: integer);
begin
  inherited Create(ADataType);
  FLockQueue := TCriticalSection.Create;
  FLockItem := TCriticalSection.Create;
  FLockSpace := TCriticalSection.Create;
  FCapacity := ACapacity;     
  FInterrupted := false;
end;

constructor TBlockingQueue.Create;
begin
  Create(System.MaxInt);
end;

constructor TBlockingQueue.Create(const ACapacity: integer);
begin
  Create(dtPointer, ACapacity)
end;

destructor TBlockingQueue.Destroy;
begin
  FInterrupted := true;
  FLockSpace.Free;
  FLockItem.Free;
  FLockQueue.Free;
  inherited;
end;

procedure TBlockingQueue.DoSleep(const AMilliSeconds: cardinal);
var
  LCurThread: TCustomThread;
begin
  LCurThread := TCustomThread.GetCurrentThread as TCustomThread;
  if Assigned(LCurThread) then begin
    LCurThread.Sleep(AMilliSeconds);
  end else begin
    SleepEx(AMilliSeconds, true)
  end;
end;

function TBlockingQueue.Add(const AItem): boolean;
begin
  CheckNull(Pointer(AItem));
  CheckCapacity;
  FLockQueue.Acquire;
  try
    Push(AItem);
    Result := List.IndexOf(Pointer(AItem)) >= 0;
  finally
    FLockQueue.Release;
  end;
end;

procedure TBlockingQueue.Element(var AItem);
begin
  CheckEmpty();
  FLockQueue.Acquire();
  try
    Peek(AItem)
  finally
    FLockQueue.Release();
  end;
end;

function TBlockingQueue.HasAvailableItem: boolean;
begin
  Result := Count > 0;
end;

function TBlockingQueue.HasAvailableSpace: boolean;
begin
  Result := (FCapacity > Count)
end;

procedure TBlockingQueue.CheckCapacity;
begin
  if RemainingCapacity = 0 then raise EIllegalState.Create;
end;

procedure TBlockingQueue.CheckEmpty;
begin
  if IsEmpty then raise ENoSuchElement.Create;
end;

procedure TBlockingQueue.CheckNull(const AItem: pointer);
begin
  if not Assigned(AItem) then raise ENullPointer.Create;
end;

function TBlockingQueue.Count: Integer;
begin
  FLockQueue.Acquire();
  try
    Result := inherited Count;
  finally
    FLockQueue.Release();
  end;
end;

function TBlockingQueue.IsEmpty: boolean;
begin
  FLockQueue.Acquire();
  try
    Result := inherited Count = 0;
  finally
    FLockQueue.Release();
  end;
end;

function TBlockingQueue.Offer(const AItem): boolean;
begin
  CheckNull(Pointer(AItem));
  FLockQueue.Acquire();
  try
    Result := ((FCapacity - Count) > 0);
    if Result then begin
      Push(AItem);
      Result := List.IndexOf(Pointer(AItem)) >= 0;
    end;
  finally
    FLockQueue.Release();
  end;
end;

function TBlockingQueue.Offer(const AItem;
  const ATimeOut: Int64): boolean;
begin
  CheckNull(Pointer(AItem));
  Result := false;
  FLockSpace.Acquire();
  try     
    if WaitForSpace(ATimeOut) then begin
      FLockQueue.Acquire();
      try
        Push(AItem);
        Result := List.IndexOf(Pointer(AItem)) >= 0;
      finally
        FLockQueue.Release();
      end;
    end;
  finally
    FLockSpace.Release();
  end;
end;

procedure TBlockingQueue.Peek(var AItem);
begin
  FLockQueue.Acquire();
  try
    if HasAvailableItem() then begin
      Peek(AItem);
    end;
  finally
    FLockQueue.Release();
  end;
end;

procedure TBlockingQueue.Poll(var AItem; const ATimeOut: Int64);
begin
  FLockItem.Acquire();
  try
    if WaitForItem(ATimeOut) then begin
      FLockQueue.Acquire();
      try
        Pop(AItem);
      finally
        FLockQueue.Release();
      end;
    end else Pointer(AItem) := nil;
  finally
    FLockItem.Release();
  end;
end;

procedure TBlockingQueue.Poll(var AItem);
begin
  FLockQueue.Acquire();
  try
    if HasAvailableItem() then begin
      Pop(AItem);
    end;
  finally
    FLockQueue.Release();
  end;
end;

procedure TBlockingQueue.Put(const AItem);
begin
  CheckNull(Pointer(AItem));                                
  FLockSpace.Acquire();
  try
    WaitForSpace();
    FLockQueue.Acquire();
    try
      Push(AItem)
    finally
      FLockQueue.Release();
    end;
  finally
    FLockSpace.Release();
  end;
end;

function TBlockingQueue.RemainingCapacity: integer;
begin
  FLockQueue.Acquire();
  try
    Result := FCapacity - Count;
  finally
    FLockQueue.Release();
  end;
end;

function TBlockingQueue.Remove(const AItem): boolean;
begin
  CheckEmpty();
  FLockQueue.Acquire();
  try
    Result := Remove(AItem);
  finally
    FLockQueue.Release();
  end;
end;

procedure TBlockingQueue.Take(var AItem);
begin
  FLockItem.Acquire();
  try
    WaitForItem();
    FLockQueue.Acquire();
    try
      Pop(AItem);
    finally
      FLockQueue.Release();
    end;
  finally
    FLockItem.Release();
  end;
end;

function TBlockingQueue.ToArray: TPointerArray;
var
  LList: PPointerList;
  I: Integer;
begin
  FLockQueue.Acquire;
  try
    LList := List.List;
    SetLength(Result, List.Count);
    for I := 0 to List.Count - 1 do begin
      Result[I] := LList^[I];
    end;
  finally
    FLockQueue.Release;
  end;
end;

procedure TBlockingQueue.WaitForItem;
begin
  while (Count = 0) do begin
    DoSleep(500);
  end;
end;

procedure TBlockingQueue.WaitForSpace;
begin
  while (FCapacity <= Count) do begin
    DoSleep(500);
  end;
end;

function TBlockingQueue.WaitForItem(const ATimeOut: Int64): boolean;
var
  LEntryTime: TDateTime;
begin
  LEntryTime := Now();
  while (Count = 0) and (IncMilliSecond(LEntryTime, ATimeOut) > Now()) do begin
    DoSleep(500);
  end;
  Result := HasAvailableItem();
end;

function TBlockingQueue.WaitForSpace(const ATimeOut: Int64): boolean;
var
  LEntryTime: TDateTime;
begin
  LEntryTime := Now();
  while not HasAvailableSpace() and (IncMilliSecond(LEntryTime, ATimeOut) > Now()) do begin
    DoSleep(500);
  end;
  Result := (FCapacity > Count);
end;

{ TInterfaceBlockingQueue }

function TInterfaceBlockingQueue.Add(const AItem: IInterface): boolean;
begin
  Result := inherited Add(AItem);
end;

constructor TInterfaceBlockingQueue.Create(const ADataType: TDataQueue.TDataType;
  const ACapacity: integer);
begin
  inherited Create(dtInterface, ACapacity);
end;

function TInterfaceBlockingQueue.Element: IInterface;
begin
  Result := nil;
  inherited Element(Result);
end;

function TInterfaceBlockingQueue.Offer(const AItem: IInterface): boolean;
begin
  Result := inherited Offer(AItem);
end;

function TInterfaceBlockingQueue.Offer(const AItem: IInterface;
  const ATimeOut: Int64): boolean;
begin
  Result := inherited Offer(AItem, ATimeOut);
end;

function TInterfaceBlockingQueue.Peek: IInterface;
begin
  Result := nil;
  inherited Peek(Result);
end;

function TInterfaceBlockingQueue.Poll: IInterface;
begin
  Result := nil;
  inherited Poll(Result);
end;

function TInterfaceBlockingQueue.Poll(const ATimeOut: Int64): IInterface;
begin
  Result := nil;
  inherited Poll(Result, ATimeOut);
end;

procedure TInterfaceBlockingQueue.Put(const AItem: IInterface);
begin
  inherited Put(AItem);
end;

function TInterfaceBlockingQueue.Remove(const AItem: IInterface): boolean;
begin
  Result := inherited Remove(AItem);
end;

function TInterfaceBlockingQueue.Take: IInterface;
begin
  inherited Take(Result);
end;

function TInterfaceBlockingQueue.ToArray: TInterfaceArray;
var
  LList: PPointerList;
  I: Integer;
begin
  FLockQueue.Acquire;
  try
    LList := List.List;
    SetLength(Result, List.Count);
    for I := 0 to List.Count - 1 do begin
      Result[I] := IInterface(LList^[I]);
    end;
  finally
    FLockQueue.Release;
  end;
end;

{ TObjectBlockingQueue }

function TObjectBlockingQueue.Add(const AItem: TObject): boolean;
begin
  Result := inherited Add(pointer(AItem));
end;

constructor TObjectBlockingQueue.Create(const ADataType: TDataQueue.TDataType;
  const ACapacity: integer);
begin
  inherited Create(dtObject, ACapacity);
end;

function TObjectBlockingQueue.Element: TObject;
begin
  inherited Element(pointer(Result));
end;

function TObjectBlockingQueue.Offer(const AItem: TObject): boolean;
begin
  Result := inherited Offer(pointer(AItem));
end;

function TObjectBlockingQueue.Offer(const AItem: TObject;
  const ATimeOut: Int64): boolean;
begin
  Result := inherited Offer(pointer(AItem), ATimeOut);
end;

function TObjectBlockingQueue.Peek: TObject;
begin
  inherited Peek(pointer(Result));
end;

function TObjectBlockingQueue.Poll: TObject;
begin
  inherited Poll(pointer(Result));
end;

function TObjectBlockingQueue.Poll(const ATimeOut: Int64): TObject;
begin
  inherited Poll(pointer(Result), ATimeOut);
end;

procedure TObjectBlockingQueue.Put(const AItem: TObject);
begin
  inherited Put(pointer(AItem));
end;

function TObjectBlockingQueue.Remove(const AItem: TObject): boolean;
begin
  Result := inherited Remove(pointer(AItem));
end;

function TObjectBlockingQueue.Take: TObject;
begin
  inherited Take(pointer(Result));
end;

function TObjectBlockingQueue.ToArray: TPointerArray;
var
  LList: PPointerList;
  I: Integer;
  LIntF: IInterface;
begin
  FLockQueue.Acquire;
  try
    LList := List.List;
    for I := Low(LList^) to High(LList^) do begin
      if not Assigned((LList^[I])) then Exit;
      LIntF := IInterface(LList^[I]);
      SetLength(Result, I + 1);
      Result[I] := LList^[I];
    end;
  finally
    FLockQueue.Release;
  end;
end;

end.
