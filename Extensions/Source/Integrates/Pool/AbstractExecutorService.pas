{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit AbstractExecutorService;

interface

uses
  ExecutorService, Callable, Future, RunnableFuture, Executor, DateUtils, 
  Runnable;

type
  TAbstractExecutorService = class abstract(TInterfacedObject, IExecutor, IExecutorService)
  protected
    procedure DoInvokeAny(const ATasks: TCallableList; const ATimed: boolean; ATimeOut: Int64; out AResult: pointer);
  public
    function NewTaskFor(const ATask: IRunnable; var AResult: pointer): ITaskFuture; overload;
    function NewTaskFor(const ACallable: ICallable): ITaskFuture; overload;
  public  
    //IExecutor implementation
    function GetAsObject(): TObject;
    procedure Execute(const ACommand: IRunnable); virtual; abstract;

    //IExecutorService implementation
    procedure Shutdown; virtual; abstract;
    function ShutdownNow: TRunnableArray; virtual; abstract;
    function IsShutdown: boolean; virtual; abstract;
    function IsTerminated: boolean; virtual; abstract;
    function AwaitTermination(const ATimeOut: int64): boolean; virtual; abstract;

    function Submit(const ATask: ICallable): IFuture; overload;
    function Submit(const ATask: IRunnable; var AResult: pointer): IFuture; overload;
    function Submit(const ATask: IRunnable): IFuture; overload;
    function InvokeAll(const ATasks: TCallableList): TFutureList; overload;
    function InvokeAll(const ATasks: TCallableList; ATimeOut: Int64): TFutureList; overload;
    procedure InvokeAny(const ATasks: TCallableList; out AResult: pointer); overload;
    procedure InvokeAny(const ATasks: TCallableList; ATimeOut: Int64; out AResult: pointer); overload;
  end;

implementation

uses
  FutureTask, SysUtils, Exceptions, ExecutorCompletitionService, Classes;

{ TAbstractExecutorService }

procedure TAbstractExecutorService.DoInvokeAny(const ATasks: TCallableList;
  const ATimed: boolean; ATimeOut: Int64; out AResult: pointer);
var
  LNTasks: integer;
  LFutures: TFutureList;
  LEcs: TExecutorCompletitionService;
  LEE: EExecution;
  LActive: integer;
  LFuture: IFuture;
  LEnumerator: TInterfaceListEnumerator;
  LNow: TDateTime;
  LLastTime: TDateTime;
  I: Integer;
begin
  if not Assigned(ATasks) then raise ENullPointer.Create();
  LNTasks := ATasks.Count;
  if (LNTasks = 0) then raise EIllegalArgument.Create();

  LFutures := TFutureList.Create();
  try
    LEcs := TExecutorCompletitionService.Create(Self);
    try
       try
         LEE := nil;
         if ATimed then LLastTime := Now() else LLastTime := MinDateTime;
         LEnumerator := ATasks.GetEnumerator();
         LEnumerator.MoveNext;
         LFutures.Add(LEcs.Submit(ICallable(LEnumerator.Current)));
         Dec(LNTasks);
         LActive := 1;
         while true do begin
           LFuture := LEcs.Poll();
           if not Assigned(LFuture) then begin
             if (LNTasks > 0) then begin
               Dec(LNTasks);
               LEnumerator.MoveNext;
               LFutures.Add(LEcs.Submit(ICallable(LEnumerator.Current)));
               Inc(LActive);
             end else if (LActive = 0) then begin
               Break;
             end else if (ATimed) then begin
               LFuture := LEcs.Poll(ATimeOut);
               if not Assigned(LFuture) then raise ETimeout.Create();
               LNow := Now();
               IncMilliSecond(ATimeOut, - MilliSecondsBetween(LLastTime, LNow));
               LLastTime := LNow;
             end else begin
               LFuture := LEcs.Take();
             end;
           end else begin
             Dec(LActive);
             try
               LFuture.GetResult(AResult);
               Exit;
             except
               on E: EExecution do begin
                 LEE := EExecution.Create(E.Message);
               end;
             end;
           end;
         end;

         if not Assigned(LEE) then LEE := EExecution.Create('Execution failed.');

         raise LEE;
       finally
         for I := 0 to LFutures.Count - 1 do begin
           IFuture(LFutures[I]).Cancel(true);
         end;
       end;
    finally
      LEcs.Free;
    end;
  finally
    LFutures.Free;
  end;
end;

function TAbstractExecutorService.GetAsObject: TObject;
begin
  Result := Self;
end;

function TAbstractExecutorService.InvokeAll(const ATasks: TCallableList;
  ATimeOut: Int64): TFutureList;
var
  LFutures: TFutureList;
  LDone: boolean;
  I: Integer;
  J: integer;
  LLastTime: TDateTime;
  LEnumerator: TInterfaceListEnumerator;
  LNow: TDateTime;
  LNil: pointer;
begin
  if not Assigned(ATasks) then raise ENullPointer.Create();
  LFutures := TFutureList.Create();
  LDone := false;
  try
   for I := 0 to ATasks.Count - 1 do begin
     LFutures.Add(NewTaskFor(ICallable(ATasks[I])));

     LLastTime := Now();

     LEnumerator := ATasks.GetEnumerator();
     while LEnumerator.MoveNext do begin
       Execute(IRunnable(LEnumerator.Current));
       LNow := Now();
       IncMilliSecond(ATimeOut, - MilliSecondsBetween(LLastTime, LNow));
       LLastTime := LNow;
       if (ATimeOut <= 0) then begin
         Result := LFutures;
         Exit;
       end;
     end;

     for J := 0 to LFutures.Count - 1 do begin
       if not (IFuture(LFutures[J]).IsDone()) then begin
         if (ATimeOut <= 0) then begin
           Result := LFutures;
           Exit;
         end;

         try
           LNil := nil;
           IFuture(LFutures[J]).GetResult(LNil);
         except
           on E: ECancellation do begin
           end;
           on E: EExecution do begin
           end;
           on E: ETimeOut do begin
             Result := LFutures;
             Exit;
           end;
         end;
         LNow := Now();
         IncMilliSecond(ATimeOut, - MilliSecondsBetween(LLastTime, LNow));
         LLastTime := Now();
       end;
     end;
   end;
   LDone := true;
   Result := LFutures;
  finally
    if not (LDone) then begin
      for I := 0 to LFutures.Count - 1 do begin
        IFuture(LFutures[I]).Cancel(true);
      end;
    end;
  end;
end;

function TAbstractExecutorService.InvokeAll(
  const ATasks: TCallableList): TFutureList;
var
  LFutures: TFutureList;
  LDone: boolean;
  I: integer;
  LFuture: ITaskFuture;
  LNil: pointer;
begin
  if not Assigned(ATasks) then raise ENullPointer.Create();
  LFutures := TFutureList.Create();
  LDone := false;
  try
    for I := 0 to ATasks.Count - 1 do begin
      LFuture := NewTaskFor(ICallable(ATasks[I]));
      LFutures.Add(LFuture);
      Execute(IRunnable(LFuture));
    end;
    for I := 0 to LFutures.Count - 1 do begin
      if not (IFuture(LFutures[I]).IsDone()) then begin
        try
          LNil := nil;
          IFuture(LFutures[I]).GetResult(LNil);
        except
          on E: ECancellation do begin
          end;
          on E: EExecution do begin
          end;
        end;
      end;
    end;
    LDone := true;
    Result := LFutures;
  finally
    if not (LDone) then begin
      for I := 0 to LFutures.Count - 1 do begin
        IFuture(LFutures[I]).Cancel(true);
      end;
    end;
  end;
end;

procedure TAbstractExecutorService.InvokeAny(const ATasks: TCallableList;
  ATimeOut: Int64; out AResult: pointer);
begin
  DoInvokeAny(ATasks, true, ATimeOut, AResult);
end;

function TAbstractExecutorService.NewTaskFor(
  const ACallable: ICallable): ITaskFuture;
begin
  Result := TFutureTask.Create(ACallable);
end;

function TAbstractExecutorService.NewTaskFor(const ATask: IRunnable;
  var AResult: pointer): ITaskFuture;
begin
  Result := TFutureTask.Create(ATask, AResult);
end;

procedure TAbstractExecutorService.InvokeAny(const ATasks: TCallableList;
  out AResult: pointer);
begin
  try
    DoInvokeAny(ATasks, false, 0, AResult);
  except
    on E: ETimeOut do begin
      Assert(false);
    end;
  end;
end;

function TAbstractExecutorService.Submit(const ATask: IRunnable): IFuture;
var
  LTask: ITaskFuture;
  LNil: pointer;
begin
  if not Assigned(ATask) then raise ENullPointer.Create();
  LNil := nil;
  LTask := NewTaskFor(ATask, LNil);
  Execute(LTask as IRunnable);
  Result := LTask as IFuture;
end;

function TAbstractExecutorService.Submit(const ATask: IRunnable;
  var AResult: pointer): IFuture;
var
  LTask: ITaskFuture;
begin
  if not Assigned(ATask) then raise ENullPointer.Create();
  LTask := NewTaskFor(ATask, AResult);
  Execute(LTask as IRunnable);
  Result := LTask as IFuture;
end;

function TAbstractExecutorService.Submit(const ATask: ICallable): IFuture;
var
  LTask: ITaskFuture;
begin
  if not Assigned(ATask) then raise ENullPointer.Create();
  LTask := NewTaskFor(ATask);
  Execute(LTask as IRunnable);
  Result := LTask as IFuture;
end;

end.
