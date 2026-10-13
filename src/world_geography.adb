with Ada.Text_IO;
with Ada.Integer_Text_IO;
with Ada.Float_Text_IO;
with Interfaces.C;
package body World_Geography is
   pragma Style_Checks (Off);
   use type Interfaces.C.C_float;
   procedure Load (Path : String) is
      F : Ada.Text_IO.File_Type;
      Count, Id : Integer;
      X, Y : Float;
      procedure Read_Point (P : out Raylib.Vector2) is
      begin
         Ada.Float_Text_IO.Get (F, X);
         Ada.Float_Text_IO.Get (F, Y);
         P := (Interfaces.C.C_float (X), Interfaces.C.C_float (Y));
      end Read_Point;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      Ada.Integer_Text_IO.Get (F, Count);
      if Count not in 1 .. Triangles'Length then raise Constraint_Error; end if;
      Triangle_Count := Count;
      for I in 1 .. Triangle_Count loop
         Ada.Integer_Text_IO.Get (F, Id);
         Triangles (I).Nation := Id;
         Read_Point (Triangles (I).A);
         Read_Point (Triangles (I).B);
         Read_Point (Triangles (I).C);
      end loop;
      Ada.Integer_Text_IO.Get (F, Count);
      if Count not in 1 .. Borders'Length then raise Constraint_Error; end if;
      Border_Count := Count;
      for I in 1 .. Border_Count loop
         Ada.Integer_Text_IO.Get (F, Id);
         Borders (I).Nation := Id;
         Read_Point (Borders (I).A);
         Read_Point (Borders (I).B);
      end loop;
      Ada.Text_IO.Close (F);
   exception when others =>
      if Ada.Text_IO.Is_Open (F) then Ada.Text_IO.Close (F); end if;
      Triangle_Count := 0;
      Border_Count := 0;
      raise;
   end Load;

   function Pick (Longitude, Latitude : Float) return Natural is
      P : constant Raylib.Vector2 :=
        (Interfaces.C.C_float (Longitude), Interfaces.C.C_float (Latitude));
      function Side (A, B, C : Raylib.Vector2) return Interfaces.C.C_float is
        ((B.X - A.X) * (C.Y - A.Y) - (B.Y - A.Y) * (C.X - A.X));
   begin
      for T of Triangles (1 .. Triangle_Count) loop
         if T.Nation > 0 and then Side (T.A, T.B, P) >= 0.0 and then
           Side (T.B, T.C, P) >= 0.0 and then Side (T.C, T.A, P) >= 0.0 then
            return T.Nation;
         end if;
      end loop;
      return 0;
   end Pick;
end World_Geography;
