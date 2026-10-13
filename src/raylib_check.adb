with Ada.Text_IO;
with Interfaces.C;
with Raylib;

procedure Raylib_Check is
   use type Interfaces.C.int;
   Value : constant Interfaces.C.int := Raylib.GetRandomValue (42, 42);
begin
   if Value /= 42 then
      raise Program_Error with "Raylib native library check failed";
   end if;
   Ada.Text_IO.Put_Line ("Raylib 6.0 native library linked and running.");
end Raylib_Check;
