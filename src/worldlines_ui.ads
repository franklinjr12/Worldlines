with Economy;
package Worldlines_UI is
   procedure Run (W : in out Economy.World_State; Assets : String;
                  Capture : String := ""; Smoke_Test : Boolean := False);
end Worldlines_UI;
