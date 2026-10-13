with Raylib;
package World_Geography is
   pragma Style_Checks (Off);
   type Triangle is record
      Nation : Natural := 0;
      A, B, C : Raylib.Vector2;
   end record;
   type Border is record
      Nation : Natural := 0;
      A, B : Raylib.Vector2;
   end record;
   Triangles : array (1 .. 12000) of Triangle;
   Borders : array (1 .. 14000) of Border;
   Triangle_Count, Border_Count : Natural := 0;
   procedure Load (Path : String);
   function Pick (Longitude, Latitude : Float) return Natural;
end World_Geography;
