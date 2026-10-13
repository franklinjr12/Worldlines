with Economy; use Economy;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;
package body Simulation_Tests is
   pragma Style_Checks (Off);
   procedure Run is
      A, B, Shocked, Restored : World_State;
      Ok : Boolean;
      Energy_Total, Shock_Total : Float := 0.0;
      Baseline_Output, Shock_Output : Float := 0.0;
      Trade_Observed : Boolean := False;
      Changed : Boolean := False;
      F : File_Type;
      procedure Check (Condition : Boolean; Message : String) is
      begin
         if not Condition then raise Program_Error with Message; end if;
         Put_Line ("PASS  " & Message);
      end Check;
   begin
      Initialize (A, 42);
      Initialize (B, 42);
      Check (A = B, "same seed produces exactly the same world");
      Restored := A;
      Initialize (B, 43);
      Check (A.Nations /= B.Nations, "different seeds change productive capacities");
      B := A;
      for Month in 1 .. 600 loop
         Step (A);
         Step (B);
         if not Valid (A) then raise Program_Error with "invalid state at month " & Month'Image; end if;
         if A /= B then raise Program_Error with "determinism failed"; end if;
         if A.Route_Count > 0 then Trade_Observed := True; end if;
         if A.Last_Trade_Balance_Error > Float'Max (0.5, A.Global_Trade * 0.001) then
            raise Program_Error with "trade accounting imbalance";
         end if;
      end loop;
      Check (Valid (A), "50 simulated years preserve finite nonnegative stocks, cash and bounded prices");
      Check (A = B, "600 monthly cycles remain deterministic");
      Check (Trade_Observed, "bilateral trade emerges from actual inventories");
      Check (A.Last_Trade_Balance_Error < 0.5, "buyer spending equals seller revenue plus trade friction");
      for I in Country_Id loop
         if abs (A.Nations (I).GDP - Restored.Nations (I).GDP) > 1.0 then Changed := True; end if;
      end loop;
      Check (Changed, "economic output evolves from production instead of fixed GDP growth");
      Initialize (A, 123);
      for M in 1 .. 36 loop Step (A); end loop;
      Shocked := A;
      Experiment (Shocked, 3, 4);
      for M in 1 .. 24 loop
         Step (A); Step (Shocked);
         Energy_Total := Energy_Total + A.World_Prices (Energy);
         Shock_Total := Shock_Total + Shocked.World_Prices (Energy);
         for I in Country_Id loop
            Baseline_Output := Baseline_Output + A.Nations (I).Output (Energy);
            Shock_Output := Shock_Output + Shocked.Nations (I).Output (Energy);
         end loop;
      end loop;
      Check (Shock_Output < Baseline_Output * 0.65, "energy shock reduces physical extraction");
      Check (Shock_Total > Energy_Total, "energy scarcity raises market prices");
      Check (Shocked.Energy_Shock_Months = 0, "temporary shock ends after 24 months");
      Check (Transport_Cost (A.Nations (4), A.Nations (5)) <
        Transport_Cost (A.Nations (4), A.Nations (21)), "distance affects delivered trade costs");
      B := A; Experiment (B, 2, 4);
      for M in 1 .. 60 loop Step (A); Step (B); end loop;
      Check (A.Nations /= B.Nations, "tariff intervention creates a different economic future");
      Save (A, "worldlines-test.sav", Ok);
      Check (Ok, "world snapshot saves");
      Initialize (Restored, 1);
      Load (Restored, "worldlines-test.sav", Ok);
      Check (Ok and Restored = A, "snapshot restores every country, history, event and random state");
      Step (Restored); Step (A);
      Check (Restored = A, "resumed world continues exactly like uninterrupted world");
      Create (F, Out_File, "worldlines-bad.sav"); Put_Line (F, "bad save"); Close (F);
      B := A;
      Load (B, "worldlines-bad.sav", Ok);
      Check (not Ok and B = A, "corrupt save is rejected without changing the current world");
      Export_CSV (A, "worldlines-test.csv", Ok);
      Check (Ok, "CSV export succeeds");
      Ada.Directories.Delete_File ("worldlines-test.sav");
      Ada.Directories.Delete_File ("worldlines-bad.sav");
      Ada.Directories.Delete_File ("worldlines-test.csv");
      Put_Line ("All simulation checks passed.");
   end Run;
end Simulation_Tests;
