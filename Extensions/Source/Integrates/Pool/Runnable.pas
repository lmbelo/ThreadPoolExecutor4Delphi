{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Runnable;

interface

type
  //Runnable - The Command
  IRunnable = interface
    ['{C51BDF40-3359-4FD2-809A-322BDD637C60}']
    procedure Run();
  end;

  TRunnableArray = array of IRunnable;

implementation

end.
