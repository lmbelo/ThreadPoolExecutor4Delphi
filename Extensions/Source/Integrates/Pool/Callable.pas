{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Callable;

interface

uses
  Classes;

type
  ICallable = interface
    ['{5D323039-18B6-464E-B2F0-61ACA47E9DA8}']
    procedure Call(out Result: pointer);
  end;

  TCallableList = class(TInterfaceList)
  end;

implementation

end.
