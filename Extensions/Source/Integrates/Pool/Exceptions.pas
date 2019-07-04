{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Exceptions;

interface

uses
  SysUtils;

type
  EIllegalState = class(Exception)
  public
    constructor Create();
  end;

  ENoSuchElement = class(Exception)
  public
    constructor Create();
  end;

  ENullPointer = class(Exception)
  public
    constructor Create();
  end;

  EInterrupted = class(Exception)
  public
    constructor Create();
  end;   
  
  ERejectecExecution = class(Exception)
  public
    constructor Create();
  end;

  EInvalidParameters = class(Exception)
  public
    constructor Create();
  end;

  ECoreThreadNonZeroKeepAliveTime = class(Exception)
  public
    constructor Create();
  end;

  EIllegalArgument = class(Exception)
  public
    constructor Create();
  end;

  ECancellation = class(Exception)
  end;

  EExecution = class(Exception)
  end;

  ETimeOut = class(Exception)
  public
    constructor Create();
  end;

implementation

{ EIllegalState }

constructor EIllegalState.Create;
begin
  inherited Create('Element cannot be added at this time due to capacity restrictions.');
end;

{ ENoSuchElement }

constructor ENoSuchElement.Create;
begin
  inherited Create('Queue is empty.')
end;

{ ENullPointer }

constructor ENullPointer.Create;
begin
  inherited Create('Invalid null element.');
end;

{ EInterrupted }

constructor EInterrupted.Create;
begin
  inherited Create('Execution has been interrupted.');
end;

{ ERejectecExecution }

constructor ERejectecExecution.Create;
begin
  inherited Create('Execution was rejected.');
end;

{ EInvalidParameters }

constructor EInvalidParameters.Create;
begin
  inherited Create('Invalid parameters.');
end;

{ ECoreThreadNonZeroKeepAliveTime }

constructor ECoreThreadNonZeroKeepAliveTime.Create;
begin
  inherited Create('Core threads must have nonzero keep alive times');
end;

{ EIllegalArgument }

constructor EIllegalArgument.Create;
begin
  inherited Create('Illegal argument.');
end;

{ ETimeOut }

constructor ETimeOut.Create;
begin
  inherited Create('Operation timeout.');
end;

end.
