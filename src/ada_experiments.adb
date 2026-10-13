with Ada.Command_Line;
with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Exceptions;
with Interfaces;
with Economy;
with Simulation_Tests;
with Worldlines_UI;

procedure Ada_Experiments is
   pragma Style_Checks (Off);
   use Ada.Command_Line;
   use Ada.Strings.Unbounded;
   W : Economy.World_State;
   Seed : Interfaces.Unsigned_32 := 42;
   Months : Natural := 0;
   Headless, Self_Test, Smoke : Boolean := False;
   Capture : Unbounded_String;
   Assets : Unbounded_String := To_Unbounded_String ("share");
   I : Positive := 1;
   Ok : Boolean;
begin
   while I <= Argument_Count loop
      if Argument (I) = "--self-test" then Self_Test := True;
      elsif Argument (I) = "--smoke-test" then Smoke := True;
      elsif Argument (I) = "--seed" and I < Argument_Count then
         I := I + 1; Seed := Interfaces.Unsigned_32'Value (Argument (I));
      elsif Argument (I) = "--headless" and I < Argument_Count then
         I := I + 1; Months := Natural'Value (Argument (I)); Headless := True;
      elsif Argument (I) = "--capture" and I < Argument_Count then
         I := I + 1; Capture := To_Unbounded_String (Argument (I));
      elsif Argument (I) = "--assets" and I < Argument_Count then
         I := I + 1; Assets := To_Unbounded_String (Argument (I));
      elsif Argument (I) = "--help" then
         Ada.Text_IO.Put_Line ("Worldlines: --seed N | --headless MONTHS | --self-test | --capture FILE | --smoke-test | --assets DIR");
         return;
      else
         raise Constraint_Error with "Unknown or incomplete option: " & Argument (I);
      end if;
      I := I + 1;
   end loop;
   if Self_Test then Simulation_Tests.Run; return; end if;
   Economy.Initialize (W, Seed);
   if Headless then
      for M in 1 .. Months loop Economy.Step (W); end loop;
      if not Economy.Valid (W) then raise Program_Error with "Invalid economic state"; end if;
      Economy.Export_CSV (W, "worldlines-export.csv", Ok);
      Ada.Text_IO.Put_Line (Economy.Date_Label (W.Month) & "  Output " & Economy.Money (W.Global_GDP) &
        "  Trade/year " & Economy.Money (W.Global_Trade * 12.0));
      if not Ok then raise Program_Error with "Could not export CSV"; end if;
   else
      if not Ada.Directories.Exists (To_String (Assets) & "/world.map") then
         declare
            Exe_Dir : constant String := Ada.Directories.Containing_Directory
              (Ada.Directories.Full_Name (Command_Name));
         begin
            Assets := To_Unbounded_String (Exe_Dir & "/../share");
         end;
      end if;
      Worldlines_UI.Run (W, To_String (Assets), To_String (Capture), Smoke);
   end if;
exception
   when E : others =>
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Information (E));
      Set_Exit_Status (Failure);
end Ada_Experiments;
