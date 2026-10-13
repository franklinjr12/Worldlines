with Raylib; use Raylib;
with Interfaces.C; use Interfaces.C;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Strings;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Numerics.Elementary_Functions;
with World_Geography;
with Economy; use Economy;

package body Worldlines_UI is
   pragma Style_Checks (Off);
   use Ada.Numerics.Elementary_Functions;
   Width : constant Float := 1440.0;
   Height : constant Float := 900.0;
   Map_X : constant Float := 32.0;
   Map_Y : constant Float := 266.0;
   Map_W : constant Float := 1032.0;
   Map_H : constant Float := 422.0;

   function RGB (R, G, B : Natural; A : Natural := 255) return Color is
     (unsigned_char (R), unsigned_char (G), unsigned_char (B), unsigned_char (A));
   Ink : constant Color := RGB (224, 234, 238);
   Muted : constant Color := RGB (125, 148, 159);
   Dim : constant Color := RGB (75, 100, 113);
   Mint : constant Color := RGB (97, 224, 180);
   Gold : constant Color := RGB (239, 194, 112);
   Coral : constant Color := RGB (237, 127, 121);
   Background : constant Color := RGB (11, 19, 27);
   Panel : constant Color := RGB (17, 29, 39);
   Line_Color : constant Color := RGB (35, 51, 63);
   Good_Colors : constant array (Good) of Color :=
     [RGB (125, 210, 148), Gold, RGB (196, 157, 131), RGB (142, 169, 193),
      RGB (111, 187, 224), RGB (177, 152, 235), RGB (233, 151, 182), RGB (110, 214, 206)];

   function V (X, Y : Float) return Vector2 is (C_float (X), C_float (Y));
   function R (X, Y, W, H : Float) return Rectangle is
     (C_float (X), C_float (Y), C_float (W), C_float (H));
   function Fade_Color (C : Color; Alpha : Natural) return Color is
     (C.R, C.G, C.B, unsigned_char (Natural'Min (255, Alpha)));
   function Blend (A, B : Color; Amount : Float) return Color is
      T : constant Float := Float'Max (0.0, Float'Min (1.0, Amount));
   begin
      return RGB (Natural (Float (A.R) * (1.0 - T) + Float (B.R) * T),
                  Natural (Float (A.G) * (1.0 - T) + Float (B.G) * T),
                  Natural (Float (A.B) * (1.0 - T) + Float (B.B) * T));
   end Blend;

   procedure Run (W : in out World_State; Assets : String;
                  Capture : String := ""; Smoke_Test : Boolean := False) is
      type Map_Mode is (Trade, Prosperity, Technology_Map, Resources, Production, Diplomacy);
      Mode : Map_Mode := Trade;
      Selected : Country_Id := 4;
      Inspector_Tab : Natural range 0 .. 2 := 0;
      Show_Nation_Routes : Boolean := False;
      Filter : Integer := -1;
      Paused : Boolean := True;
      Speed : Positive := 1;
      Accumulator : Float := 0.0;
      Zoom : Float := 1.0;
      Pan_X, Pan_Y : Float := 0.0;
      Mouse : Vector2 := V (0.0, 0.0);
      Previous_Mouse : Vector2 := V (0.0, 0.0);
      Click, Down : Boolean := False;
      Hover_Button : Boolean := False;
      Dirty : Boolean := True;
      Font_Normal, Font_Bold, Font_Title : Font;
      Canvas, Map_Cache : RenderTexture;
      Scale, Screen_X, Screen_Y : Float;
      Frames : Natural := 0;
      Modal : Natural := 0;
      Event_Offset : Natural := 0;
      Seed_Input : Unbounded_String := To_Unbounded_String ("42");
      Status : Unbounded_String := To_Unbounded_String ("Select a country. Follow the goods. Change the future.");
      Status_Time : Float := 0.0;
      Ok : Boolean;
      Save_Path : constant String := "worldlines.sav";
      CSV_Path : constant String := "worldlines-export.csv";
      Top_Routes : array (1 .. 90) of Natural := [others => 0];
      Top_Count : Natural := 0;
      Route_Month : Integer := -1;
      Route_Selected : Natural := 0;
      Route_Filter : Integer := -2;
      Route_Focus : Boolean := False;
      function Seed_Label return String is
        (Ada.Strings.Fixed.Trim (Interfaces.Unsigned_32'Image (W.Seed), Ada.Strings.Both));
      Help_Text : constant array (1 .. 9) of Unbounded_String :=
        [To_Unbounded_String ("SPACE    Pause / resume       RIGHT    Advance one month"),
         To_Unbounded_String ("1 / 2 / 3 / 4    Set speed       TAB    Cycle map layers"),
         To_Unbounded_String ("Mouse wheel    Zoom map       Middle-drag    Pan map"),
         To_Unbounded_String ("F5    Save world       F9    Load world       S    Export CSV"),
         To_Unbounded_String ("E    Open experiments       R    New world       H    This guide"),
         To_Unbounded_String ("Click a country or use the inspector arrows to explore all 36 economies."),
         To_Unbounded_String ("Production consumes inputs. Imports compete on delivered price and available cash."),
         To_Unbounded_String ("Prices respond to inventories. Capital and machinery fund autonomous investment."),
         To_Unbounded_String ("Starting economies are illustrative; simulated futures are experiments, not forecasts.")];

      procedure Text (S : String; X, Y : Float; Size : Float := 15.0;
                      C : Color := Ink; Bold : Boolean := False) is
      begin
         DrawTextEx ((if Bold then Font_Bold else Font_Normal), S,
                     V (X, Y), C_float (Size), 0.25, C);
      end Text;
      procedure Rule (X, Y, Length : Float) is
      begin DrawLineEx (V (X, Y), V (X + Length, Y), 1.0, Line_Color); end Rule;
      procedure Box (X, Y, WW, HH : Float; C : Color := Panel) is
      begin DrawRectangleRounded (R (X, Y, WW, HH), 0.08, 6, C); end Box;
      function Within (X, Y, WW, HH : Float) return Boolean is
        (Float (Mouse.X) >= X and Float (Mouse.X) <= X + WW and
         Float (Mouse.Y) >= Y and Float (Mouse.Y) <= Y + HH);
      function Button (S : String; X, Y, WW : Float; Active : Boolean := False;
                       HH : Float := 32.0; Accent : Boolean := False) return Boolean is
         Hover : constant Boolean := Within (X, Y, WW, HH);
         Allowed : constant Boolean := Modal = 0 or (X >= 355.0 and X <= 1085.0 and Y >= 218.0 and Y <= 748.0);
         BG : Color := (if Accent then RGB (37, 89, 74) elsif Active then RGB (39, 59, 70) else RGB (22, 36, 46));
         TW : Float;
      begin
         if Hover and Allowed then BG := Blend (BG, Mint, 0.16); Hover_Button := True; end if;
         Box (X, Y, WW, HH, BG);
         if Active then DrawRectangleRoundedLinesEx (R (X, Y, WW, HH), 0.12, 6, 1.0, RGB (62, 93, 106)); end if;
         TW := Float (MeasureTextEx (Font_Normal, S, 14.0, 0.25).X);
         Text (S, X + (WW - TW) / 2.0, Y + (HH - 17.0) / 2.0, 14.0,
               (if Accent or Active then Mint else Ink));
         return Hover and Click and Allowed;
      end Button;
      procedure Notify (S : String) is
      begin Status := To_Unbounded_String (S); Status_Time := 6.0; end Notify;
      function Project (P : Vector2) return Vector2 is
      begin
         return V (Map_X + Map_W / 2.0 + Float (P.X) / 360.0 * Map_W * Zoom + Pan_X,
           Map_Y + (82.0 - Float (P.Y)) / 145.0 * Map_H * Zoom - (Zoom - 1.0) * Map_H / 2.0 + Pan_Y);
      end Project;
      function Nation_Point (I : Country_Id) return Vector2 is
        (Project (V (W.Nations (I).Longitude, W.Nations (I).Latitude)));
      function Country_Color (Id : Natural) return Color is
         Value : Float;
         Best : Good := Food;
         Bloc_Colors : constant array (0 .. 5) of Color :=
           [RGB (84, 111, 125), RGB (86, 162, 192), RGB (159, 136, 211),
            RGB (104, 186, 146), RGB (211, 165, 107), RGB (203, 127, 145)];
      begin
         if Id = 0 then return RGB (27, 43, 54); end if;
         declare C : Country renames W.Nations (Id); begin
            case Mode is
               when Prosperity =>
                  Value := C.Prosperity / 100.0;
                  return Blend (RGB (71, 63, 74), RGB (74, 167, 138), Value);
               when Technology_Map =>
                  return Blend (RGB (42, 53, 78), RGB (165, 145, 225), Average_Tech (C) / 10.0);
               when Resources =>
                  for G in Food .. Minerals loop if C.Resources (G) > C.Resources (Best) then Best := G; end if; end loop;
                  return Blend (RGB (32, 50, 57), Good_Colors (Best), Float'Min (0.65, C.Resources (Best) / 5.0));
               when Production =>
                  for G in Good loop
                     if C.Output (G) * Base_Prices (G) > C.Output (Best) * Base_Prices (Best) then Best := G; end if;
                  end loop;
                  return Blend (RGB (34, 49, 59), Good_Colors (Best), 0.52);
               when Diplomacy => return Blend (RGB (23, 37, 46), Bloc_Colors (C.Bloc), 0.60);
               when Trade => return Blend (RGB (30, 51, 60), RGB (57, 108, 107), C.Prosperity / 140.0);
            end case;
         end;
      end Country_Color;

      procedure Build_Map is
         Col : Color;
         A, B, C : Vector2;
      begin
         BeginTextureMode (Map_Cache);
         ClearBackground (RGB (0, 0, 0, 0));
         DrawRectangleRec (R (Map_X, Map_Y, Map_W, Map_H), RGB (13, 25, 34));
         BeginScissorMode (int (Map_X), int (Map_Y), int (Map_W), int (Map_H));
         for Lon in -6 .. 6 loop
            A := Project (V (Float (Lon) * 30.0, 82.0));
            B := Project (V (Float (Lon) * 30.0, -63.0));
            DrawLineEx (A, B, 1.0, RGB (25, 39, 49));
         end loop;
         for Lat in -2 .. 2 loop
            A := Project (V (-180.0, Float (Lat) * 30.0));
            B := Project (V (180.0, Float (Lat) * 30.0));
            DrawLineEx (A, B, 1.0, RGB (25, 39, 49));
         end loop;
         for T of World_Geography.Triangles (1 .. World_Geography.Triangle_Count) loop
            Col := Country_Color (T.Nation);
            if T.Nation = Selected then Col := Blend (Col, Mint, 0.30); end if;
            A := Project (T.A); B := Project (T.B); C := Project (T.C);
            --  Geographic triangles are CCW; projection flips latitude to screen coordinates.
            DrawTriangle (A, B, C, Col);
         end loop;
         for Edge of World_Geography.Borders (1 .. World_Geography.Border_Count) loop
            DrawLineEx (Project (Edge.A), Project (Edge.B),
              (if Edge.Nation = Selected then 1.4 else 0.7),
              (if Edge.Nation = Selected then Mint else RGB (60, 82, 93)));
         end loop;
         EndScissorMode;
         EndTextureMode;
         Dirty := False;
      end Build_Map;

      procedure Update_Routes is
         Pos : Natural;
      begin
         Top_Count := 0;
         Top_Routes := [others => 0];
         for I in 1 .. W.Route_Count loop
            if (Filter = -1 or else Good'Pos (W.Routes (I).Product) = Filter) and then
              (not Show_Nation_Routes or else W.Routes (I).Seller = Selected or else W.Routes (I).Buyer = Selected) then
               Pos := 1;
               while Pos <= Top_Count and then W.Routes (Top_Routes (Pos)).Value >= W.Routes (I).Value loop Pos := Pos + 1; end loop;
               if Pos <= 90 then
                  Top_Count := Natural'Min (90, Top_Count + 1);
                  for J in reverse Pos + 1 .. Top_Count loop Top_Routes (J) := Top_Routes (J - 1); end loop;
                  Top_Routes (Pos) := I;
               end if;
            end if;
         end loop;
         Route_Month := Integer (W.Month);
         Route_Selected := Selected;
         Route_Filter := Filter;
         Route_Focus := Show_Nation_Routes;
      end Update_Routes;

      procedure Draw_Routes is
         A, B, Control, Particle : Vector2;
         DX, DY, T, Phase, Thick, Dist : Float;
         Col : Color;
         Related : Boolean;
         Motion : constant Float := (if Paused then Float (W.Month) * 0.071 else Float (GetTime) * 0.14);
      begin
         if Route_Month /= Integer (W.Month) or Route_Selected /= Selected or
           Route_Filter /= Filter or Route_Focus /= Show_Nation_Routes then Update_Routes; end if;
         BeginScissorMode (int (Map_X), int (Map_Y), int (Map_W), int (Map_H));
         for Rank in reverse 1 .. Top_Count loop
            declare Route : Trade_Route renames W.Routes (Top_Routes (Rank)); begin
               A := Nation_Point (Route.Seller); B := Nation_Point (Route.Buyer);
               DX := Float (B.X - A.X); DY := Float (B.Y - A.Y);
               if abs DX > Map_W * Zoom / 2.0 then
                  B.X := B.X + C_float ((if DX > 0.0 then -1.0 else 1.0) * Map_W * Zoom);
                  DX := Float (B.X - A.X);
               end if;
               Dist := Sqrt (DX * DX + DY * DY);
               Control := V (Float (A.X + B.X) / 2.0, Float (A.Y + B.Y) / 2.0 - Float'Min (100.0, Dist * 0.18));
               Related := Route.Seller = Selected or Route.Buyer = Selected;
               Col := Fade_Color (Good_Colors (Route.Product), (if Related then 155 else 58));
               Thick := Float'Min (2.2, 0.6 + Sqrt (Route.Value) * 0.23);
               for Wrap in -1 .. 1 loop
                  declare Shift : constant C_float := C_float (Float (Wrap) * Map_W * Zoom);
                     AA : constant Vector2 := (A.X + Shift, A.Y);
                     BB : constant Vector2 := (B.X + Shift, B.Y);
                     CC : constant Vector2 := (Control.X + Shift, Control.Y);
                  begin
                     DrawSplineSegmentBezierQuadratic (AA, CC, BB, C_float (Thick), Col);
                     Phase := Motion + Float (Rank) * 0.137;
                     T := Phase - Float (Integer (Float'Floor (Phase)));
                     Particle := V ((1.0 - T) ** 2 * Float (AA.X) + 2.0 * (1.0 - T) * T * Float (CC.X) + T ** 2 * Float (BB.X),
                       (1.0 - T) ** 2 * Float (AA.Y) + 2.0 * (1.0 - T) * T * Float (CC.Y) + T ** 2 * Float (BB.Y));
                     DrawCircleV (Particle, (if Related then 2.4 else 1.6), Fade_Color (Good_Colors (Route.Product), (if Related then 235 else 135)));
                  end;
               end loop;
            end;
         end loop;
         EndScissorMode;
      end Draw_Routes;

      procedure Draw_Map is
         P : Vector2;
         Names : constant array (Map_Mode) of Unbounded_String :=
           [To_Unbounded_String ("Trade flows"), To_Unbounded_String ("Prosperity"), To_Unbounded_String ("Technology"),
            To_Unbounded_String ("Resources"), To_Unbounded_String ("Production"), To_Unbounded_String ("Trade blocs")];
         Legend : Unbounded_String;
         X : Float := 32.0;
      begin
         for M in Map_Mode loop
            if Button (To_String (Names (M)), X, 203.0, 112.0, Mode = M) then Mode := M; Dirty := True; end if;
            X := X + 117.0;
         end loop;
         if Button ((if Filter = -1 then "All goods" else Good_Name (Good'Val (Filter))), 769.0, 203.0, 143.0) then
            Filter := (if Filter >= 6 then -1 else Filter + 1);
         end if;
         if Button ((if Show_Nation_Routes then "Country routes" else "World routes"), 922.0, 203.0, 143.0, Show_Nation_Routes) then
            Show_Nation_Routes := not Show_Nation_Routes;
         end if;
         Text ("THE CONNECTED WORLD", 32.0, 249.0, 11.0, Muted, True);
         Text ("36 economies  /  " & Number (Float (W.Route_Count), 0) & " shipments this month", 786.0, 249.0, 11.0, Muted);
         DrawTextureRec (Map_Cache.Texture_F, R (0.0, 0.0, Width, -Height), V (0.0, 0.0), RGB (255, 255, 255));
         if Mode = Trade then Draw_Routes; end if;
         BeginScissorMode (int (Map_X), int (Map_Y), int (Map_W), int (Map_H));
         for I in Country_Id loop
            P := Nation_Point (I);
            DrawCircleV (P, (if I = Selected then 4.0 else 2.0), (if I = Selected then Mint else RGB (102, 148, 158)));
            if I = Selected then
               DrawCircleLinesV (P, 9.0, Fade_Color (Mint, 130));
               Box (Float (P.X) + 12.0, Float (P.Y) - 12.0, Float (MeasureTextEx (Font_Bold, Name_Of (W.Nations (I)), 13.0, 0.25).X) + 20.0, 27.0, RGB (20, 43, 48));
               Text (Name_Of (W.Nations (I)), Float (P.X) + 22.0, Float (P.Y) - 8.0, 13.0, Mint, True);
            elsif I in 1 | 4 | 10 | 18 | 19 | 20 | 21 | 27 | 31 then
               Text (W.Nations (I).ISO, Float (P.X) + 6.0, Float (P.Y) - 8.0, 10.0, RGB (142, 172, 180));
            end if;
         end loop;
         Text ("PACIFIC OCEAN", 72.0, 510.0, 12.0, Dim);
         Text ("ATLANTIC", 426.0, 432.0, 11.0, Dim);
         Text ("INDIAN OCEAN", 740.0, 599.0, 11.0, Dim);
         EndScissorMode;
         --  Country geometry is cached as a transparent layer; toolbar remains outside its crop.
         DrawRectangleLinesEx (R (Map_X, Map_Y, Map_W, Map_H), 1.0, Line_Color);
         case Mode is
            when Trade => Legend := To_Unbounded_String ("Moving dots: seller to buyer  /  Width: shipment value  /  Color: traded good");
            when Prosperity => Legend := To_Unbounded_String ("Muted: unmet needs    ->    Green: higher consumption and productive knowledge");
            when Technology_Map => Legend := To_Unbounded_String ("Dark: lower technology    ->    Lavender: higher technology  /  Five research fields");
            when Resources => Legend := To_Unbounded_String ("Dominant endowment: green food  /  gold energy  /  copper minerals");
            when Production => Legend := To_Unbounded_String ("Country color: largest sector by real output value  /  Goods palette below");
            when Diplomacy => Legend := To_Unbounded_String ("Blue: North America  /  Purple: Europe  /  Green: S. America  /  Gold: Asia-Pacific  /  Rose: Africa");
         end case;
         Text (To_String (Legend), 32.0, 696.0, 11.0, Muted);
         if Button ("-", 973.0, 647.0, 27.0, HH => 27.0) then Zoom := Float'Max (1.0, Zoom - 0.25); Dirty := True; end if;
         if Button ("+", 1005.0, 647.0, 27.0, HH => 27.0) then Zoom := Float'Min (3.0, Zoom + 0.25); Dirty := True; end if;
         if Button ("Fit", 1037.0, 647.0, 27.0, HH => 27.0) then Zoom := 1.0; Pan_X := 0.0; Pan_Y := 0.0; Dirty := True; end if;
      end Draw_Map;

      procedure Chart (Values : History_Array; X, Y, WW, HH : Float; C : Color) is
         Count : constant Natural := Natural'Min (119, W.Month);
         Low : Float := Float'Last;
         High : Float := 0.0;
         Value : Float;
         A, B : Vector2;
      begin
         for J in 0 .. Count loop
            Value := Values ((W.Month - Count + J) mod 120);
            Low := Float'Min (Low, Value); High := Float'Max (High, Value);
         end loop;
         Low := Low * 0.94; High := High * 1.04 + 0.01;
         for J in 0 .. 2 loop Rule (X, Y + Float (J) * HH / 2.0, WW); end loop;
         if Count > 0 then
            for J in 1 .. Count loop
               A := V (X + Float (J - 1) / Float (Count) * WW,
                 Y + HH * (1.0 - (Values ((W.Month - Count + J - 1) mod 120) - Low) / (High - Low)));
               B := V (X + Float (J) / Float (Count) * WW,
                 Y + HH * (1.0 - (Values ((W.Month - Count + J) mod 120) - Low) / (High - Low)));
               DrawLineEx (A, B, 2.0, C);
               DrawLineEx (V (Float (B.X), Float (B.Y)), V (Float (B.X), Y + HH), 1.5, Fade_Color (C, 22));
            end loop;
            DrawCircleV (B, 3.0, C);
         else
            DrawLineEx (V (X, Y + HH / 2.0), V (X + WW, Y + HH / 2.0), 2.0, C);
         end if;
         Text (Date_Label (W.Month - Count), X, Y + HH + 6.0, 10.0, Muted);
         Text (Date_Label (W.Month), X + WW - 47.0, Y + HH + 6.0, 10.0, Muted);
      end Chart;

      procedure Slider (Label : String; Value : in out Float; X, Y : Float; Max : Float := 1.0) is
      begin
         Text (Label, X, Y, 14.0);
         Text (Number (Value * 100.0, 0) & "%", X + 218.0, Y, 14.0, Mint, True);
         Box (X, Y + 28.0, 266.0, 5.0, RGB (41, 59, 70));
         Box (X, Y + 28.0, 266.0 * Value / Max, 5.0, Mint);
         DrawCircleV (V (X + 266.0 * Value / Max, Y + 30.5), 6.0, Mint);
         if Modal = 0 and Within (X - 4.0, Y + 19.0, 274.0, 24.0) then
            Hover_Button := True;
            if Down then
               Value := Float'Max (0.0, Float'Min (Max, (Float (Mouse.X) - X) / 266.0 * Max));
               W.Nations (Selected).Manual_Policy := True;
            end if;
         end if;
      end Slider;

      procedure Draw_Inspector is
         C : Country renames W.Nations (Selected);
         Total_Output, Imports, Exports : Float := 0.0;
         YY : Float;
         Best_Partner : Natural := 0;
         Partner_Values : array (Country_Id) of Float := [others => 0.0];
      begin
         Box (1092.0, 96.0, 320.0, 757.0);
         Text ("COUNTRY OBSERVATORY", 1116.0, 115.0, 11.0, Muted, True);
         if Button ("<", 1342.0, 108.0, 25.0, HH => 25.0) then
            Selected := (if Selected = Country_Id'First then Country_Id'Last else Selected - 1); Dirty := True;
         end if;
         if Button (">", 1374.0, 108.0, 25.0, HH => 25.0) then
            Selected := (if Selected = Country_Id'Last then Country_Id'First else Selected + 1); Dirty := True;
         end if;
         Text (Name_Of (C), 1116.0, 143.0, (if Name_Of (C)'Length > 18 then 23.0 else 29.0), Ink, True);
         Text (C.ISO & "  /  " & Priority_Name (C.Priority), 1116.0, 181.0, 12.0, Mint);
         Text (Bloc_Name (C.Bloc), 1116.0, 201.0, 12.0, Muted);
         if Button ("Economy", 1116.0, 232.0, 87.0, Inspector_Tab = 0) then Inspector_Tab := 0; end if;
         if Button ("Policies", 1210.0, 232.0, 87.0, Inspector_Tab = 1) then Inspector_Tab := 1; end if;
         if Button ("Research", 1304.0, 232.0, 83.0, Inspector_Tab = 2) then Inspector_Tab := 2; end if;
         if Inspector_Tab = 2 then
            Text ("Productive knowledge", 1116.0, 285.0, 20.0, Ink, True);
            Text (Number (Average_Tech (C), 2) & " / 10 average technology", 1116.0, 316.0, 13.0, Mint);
            YY := 356.0;
            for T in Technology loop
               Text (Tech_Name (T), 1116.0, YY, 14.0);
               Text (Number (C.Tech (T), 2), 1347.0, YY, 14.0, Good_Colors (Electronics), True);
               Box (1116.0, YY + 27.0, 271.0, 6.0, RGB (41, 59, 70));
               Box (1116.0, YY + 27.0, 271.0 * C.Tech (T) / 10.0, 6.0, Good_Colors (Electronics));
               YY := YY + 61.0;
            end loop;
            Rule (1116.0, 674.0, 271.0);
            Text ("Infrastructure", 1116.0, 695.0, 14.0, Muted);
            Text (Number (C.Infrastructure, 2) & " / 10", 1310.0, 695.0, 14.0, Mint);
            Text ("Research raises productivity gradually.", 1116.0, 734.0, 12.0, Muted);
            Text ("Advanced industry builds on manufacturing.", 1116.0, 757.0, 12.0, Muted);
            Text ("Trade brings knowledge from partners.", 1116.0, 780.0, 12.0, Muted);
            Text ("Better logistics lowers delivered costs.", 1116.0, 815.0, 12.0, Mint);
            return;
         end if;
         if Inspector_Tab = 1 then
            Text ("Shape the incentives", 1116.0, 285.0, 20.0, Ink, True);
            Text ("Changes apply from the next month.", 1116.0, 315.0, 12.0, Muted);
            Slider ("Import tariff", C.Tariff, 1116.0, 348.0, 0.60);
            Slider ("Industrial investment", C.Industry_Budget, 1116.0, 414.0);
            Slider ("Education & research", C.Research_Budget, 1116.0, 480.0);
            Slider ("Infrastructure", C.Infrastructure_Budget, 1116.0, 546.0);
            if Button ((if C.Manual_Policy then "Player policy  /  Restore autonomy" else "Autonomous government"), 1116.0, 617.0, 271.0, not C.Manual_Policy) then
               C.Manual_Policy := not C.Manual_Policy;
               if not C.Manual_Policy then
                  C.Industry_Budget := (if C.Priority = Industrialist then 0.50 else 0.32);
                  C.Research_Budget := (if C.Priority = Knowledge_First then 0.45 else 0.23);
                  C.Infrastructure_Budget := 0.22;
               end if;
               Add_Event (W, Name_Of (C) & " changes policy control.", Selected);
            end if;
            Rule (1116.0, 677.0, 271.0);
            Text ("WHERE CAPITAL IS GOING", 1116.0, 694.0, 11.0, Muted, True);
            Text (Good_Name (C.Last_Investment), 1116.0, 718.0, 19.0, Good_Colors (C.Last_Investment), True);
            Text ("Price signals, resources and national", 1116.0, 751.0, 12.0, Muted);
            Text ("priorities guide each investment.", 1116.0, 770.0, 12.0, Muted);
            Text ("Funding competes with other priorities.", 1116.0, 816.0, 11.0, Dim);
            return;
         end if;
         Text ("REAL OUTPUT / YEAR", 1116.0, 288.0, 10.0, Muted, True);
         Text (Money (C.GDP), 1116.0, 307.0, 28.0, Ink, True);
         Text ((if C.Growth >= 0.0 then "+" else "") & Number (C.Growth, 2) & "% month", 1274.0, 318.0, 12.0,
           (if C.Growth >= 0.0 then Mint else Coral));
         Chart (C.GDP_History, 1116.0, 353.0, 271.0, 69.0, Mint);
         Text ("Population", 1116.0, 456.0, 12.0, Muted);
         Text (Number (C.Population, 1) & "M", 1270.0, 456.0, 14.0, Ink, True);
         Text ("Capital reserves", 1116.0, 481.0, 12.0, Muted);
         Text (Money (C.Capital), 1270.0, 481.0, 14.0, Ink, True);
         Text ("Prosperity", 1116.0, 507.0, 12.0, Muted);
         Text (Number (C.Prosperity, 0) & " / 100", 1270.0, 507.0, 14.0, Mint, True);
         Text ("Demand met", 1116.0, 533.0, 12.0, Muted);
         Text (Number ((1.0 - C.Shortage) * 100.0, 0) & "%", 1270.0, 533.0, 14.0,
           (if C.Shortage > 0.2 then Coral else Ink), True);
         Rule (1116.0, 563.0, 271.0);
         Text ("PRODUCTION MIX", 1116.0, 579.0, 10.0, Muted, True);
         for G in Good loop Total_Output := Total_Output + C.Output (G) * Base_Prices (G); end loop;
         YY := 602.0;
         for G in Good loop
            DrawCircleV (V (1120.0, YY + 7.0), 3.0, Good_Colors (G));
            Text (Good_Name (G), 1130.0, YY, 11.0, Muted);
            Box (1234.0, YY + 3.0, 98.0, 7.0, RGB (34, 51, 63));
            Box (1234.0, YY + 3.0, 98.0 * C.Output (G) * Base_Prices (G) / Float'Max (0.01, Total_Output), 7.0, Good_Colors (G));
            Text (Number (C.Output (G) * Base_Prices (G) / Float'Max (0.01, Total_Output) * 100.0, 0) & "%", 1341.0, YY, 11.0);
            YY := YY + 19.0;
            Imports := Imports + C.Imports (G); Exports := Exports + C.Exports (G);
         end loop;
         Rule (1116.0, 766.0, 271.0);
         for I in 1 .. W.Route_Count loop
            if W.Routes (I).Seller = Selected then Partner_Values (W.Routes (I).Buyer) := Partner_Values (W.Routes (I).Buyer) + W.Routes (I).Value; end if;
            if W.Routes (I).Buyer = Selected then Partner_Values (W.Routes (I).Seller) := Partner_Values (W.Routes (I).Seller) + W.Routes (I).Value; end if;
         end loop;
         for I in Country_Id loop
            if Partner_Values (I) > 0.0 and then (Best_Partner = 0 or else Partner_Values (I) > Partner_Values (Best_Partner)) then Best_Partner := I; end if;
         end loop;
         Text ("TRADE / MONTH", 1116.0, 783.0, 10.0, Muted, True);
         Text ("Out " & Money (Exports) & "   In " & Money (Imports), 1116.0, 801.0, 13.0, Ink);
         Text ((if Best_Partner = 0 then "No affordable trade partners this month" else "Top partner: " & Name_Of (W.Nations (Best_Partner))), 1116.0, 827.0, 11.0, Mint);
      end Draw_Inspector;

      procedure Draw_Markets is
         X, Y, Index : Float;
      begin
         Box (28.0, 726.0, 611.0, 127.0);
         Text ("THE MARKET PULSE", 46.0, 740.0, 11.0, Muted, True);
         Text ("Local price average / baseline", 433.0, 740.0, 10.0, Dim);
         for G in Good loop
            X := 46.0 + Float (Good'Pos (G) mod 4) * 149.0;
            Y := 766.0 + Float (Good'Pos (G) / 4) * 41.0;
            DrawCircleV (V (X + 3.0, Y + 7.0), 3.0, Good_Colors (G));
            Text (Good_Name (G), X + 13.0, Y, 11.0, Muted);
            Index := W.World_Prices (G) / Base_Prices (G);
            Text (Number (Index, 2) & "x", X + 13.0, Y + 15.0, 15.0,
              (if Index > 1.4 then Coral elsif Index < 0.65 then Gold else Ink), True);
            if Modal = 0 and Within (X, Y, 135.0, 37.0) then
               Hover_Button := True;
               if Click then Filter := (if Filter = Good'Pos (G) then -1 else Good'Pos (G)); Mode := Trade; Dirty := True; end if;
            end if;
         end loop;
      end Draw_Markets;

      procedure Draw_Feed is
         YY : Float := 769.0;
         S : Unbounded_String;
      begin
         Box (655.0, 726.0, 413.0, 127.0);
         Text ("WORLD DISPATCH", 674.0, 740.0, 11.0, Muted, True);
         if Button ("View all", 981.0, 735.0, 70.0, HH => 25.0) then Modal := 4; Event_Offset := 0; end if;
         for I in 1 .. Natural'Min (3, W.Event_Count) loop
            S := To_Unbounded_String (Ada.Strings.Fixed.Trim (W.Events (I).Text, Ada.Strings.Right));
            Text (Date_Label (W.Events (I).Month), 674.0, YY, 10.0, Mint);
            if Length (S) > 48 then S := To_Unbounded_String (Slice (S, 1, 45) & "..."); end if;
            Text (To_String (S), 735.0, YY - 1.0, 11.0, Ink);
            if Modal = 0 and Within (674.0, YY - 2.0, 372.0, 24.0) then
               Hover_Button := True;
               if Click then
                  Notify (Ada.Strings.Fixed.Trim (W.Events (I).Text, Ada.Strings.Right));
                  if W.Events (I).Nation > 0 then Selected := W.Events (I).Nation; Dirty := True; end if;
               end if;
            end if;
            YY := YY + 25.0;
         end loop;
      end Draw_Feed;

      procedure Draw_Header is
         Population, Prosperity_Sum : Float := 0.0;
         X : Float;
         Labels : constant array (1 .. 4) of Unbounded_String :=
           [To_Unbounded_String ("REAL GLOBAL OUTPUT"), To_Unbounded_String ("TRADE / YEAR"),
            To_Unbounded_String ("SIMULATED POPULATION"), To_Unbounded_String ("AVERAGE PROSPERITY")];
         Values : array (1 .. 4) of Unbounded_String;
         Speeds : constant array (1 .. 4) of Positive := [1, 5, 20, 100];
      begin
         DrawRectangleRec (R (0.0, 0.0, Width, 76.0), RGB (15, 25, 34));
         DrawCircleLinesV (V (45.0, 37.0), 14.0, Mint);
         DrawEllipseLines (45, 37, 7.0, 14.0, Mint);
         DrawLineEx (V (31.0, 37.0), V (59.0, 37.0), 1.0, Mint);
         DrawTextEx (Font_Title, "Worldlines", V (71.0, 17.0), 34.0, 0.3, Ink);
         Text ("A LIVING TRADE SIMULATION", 254.0, 33.0, 10.0, Dim, True);
         if Button ("Experiments", 493.0, 23.0, 109.0) then Modal := 1; end if;
         if Button ("New world", 612.0, 23.0, 93.0) then Modal := 3; Seed_Input := To_Unbounded_String (Seed_Label); end if;
         if Button ("?", 715.0, 23.0, 30.0) then Modal := 2; end if;
         Text (Date_Label (W.Month), 792.0, 24.0, 23.0, Ink, True);
         if Button ((if Paused then "Play >" else "Pause"), 942.0, 23.0, 81.0, Accent => True) then Paused := not Paused; end if;
         if Button ("Step", 1032.0, 23.0, 53.0) then Step (W); Dirty := True; end if;
         X := 1094.0;
         for S of Speeds loop
            if Button ((if S = 100 then "MAX" else Number (Float (S), 0) & "x"), X, 23.0, 45.0, Speed = S) then Speed := S; end if;
            X := X + 49.0;
         end loop;
         if Button ("Save", 1301.0, 23.0, 49.0) then Save (W, Save_Path, Ok); Notify ((if Ok then "Saved worldlines.sav" else "Could not save world.")); end if;
         if Button ("Load", 1359.0, 23.0, 49.0) then
            Load (W, Save_Path, Ok); Dirty := True; Route_Month := -1;
            Notify ((if Ok then "World restored. Its random state and history resume exactly." else "No valid worldlines.sav found."));
         end if;
         Text ("Every shipment connects a story.", 32.0, 93.0, 16.0, Muted);
         Text ("START 2025  /  SEED " & Seed_Label & "  /  ILLUSTRATIVE ECONOMIES", 677.0, 98.0, 10.0, Dim);
         for C of W.Nations loop Population := Population + C.Population; Prosperity_Sum := Prosperity_Sum + C.Prosperity; end loop;
         Values (1) := To_Unbounded_String (Money (W.Global_GDP));
         Values (2) := To_Unbounded_String (Money (W.Global_Trade * 12.0));
         Values (3) := To_Unbounded_String (Number (Population / 1000.0, 2) & "B");
         Values (4) := To_Unbounded_String (Number (Prosperity_Sum / Float (Country_Count), 1) & " / 100");
         for I in 1 .. 4 loop
            X := 28.0 + Float (I - 1) * 264.0;
            Box (X, 124.0, 248.0, 63.0);
            Text (To_String (Labels (I)), X + 15.0, 135.0, 10.0, Muted, True);
            Text (To_String (Values (I)), X + 15.0, 153.0, 24.0, (if I = 2 then Mint else Ink), True);
         end loop;
      end Draw_Header;

      procedure Draw_Modal is
         YY : Float;
         Choice : Natural := 0;
         Titles : constant array (1 .. 5) of Unbounded_String :=
           [To_Unbounded_String ("Industrialize " & Name_Of (W.Nations (Selected))),
            To_Unbounded_String ("A world behind tariffs"), To_Unbounded_String ("The energy squeeze"),
            To_Unbounded_String ("An open African market"), To_Unbounded_String ("Manufacturing breakthrough")];
         Descriptions : constant array (1 .. 5) of Unbounded_String :=
           [To_Unbounded_String ("Raise industrial investment and research. Follow the slow returns."),
            To_Unbounded_String ("Set every country's tariffs to 40%. Watch supply chains reorganize."),
            To_Unbounded_String ("Cut world energy extraction by 55% for two years."),
            To_Unbounded_String ("Remove tariffs for the six simulated African economies."),
            To_Unbounded_String ("Add two manufacturing levels to the selected country.")];
         Key : int;
         Event_Index : Natural;
         Event_Text : Unbounded_String;
         Wheel : Float;
      begin
         DrawRectangleRec (R (0.0, 0.0, Width, Height), RGB (3, 9, 15, 205));
         Box (355.0, 218.0, 730.0, 530.0, RGB (22, 36, 47));
         if Button ("Close", 999.0, 239.0, 62.0) then Modal := 0; return; end if;
         if Modal = 1 then
            Text ("Change one thing. Follow the consequences.", 384.0, 244.0, 25.0, Ink, True);
            Text ("Experiments preserve the current world. Save first to compare alternate futures.", 384.0, 282.0, 13.0, Muted);
            YY := 322.0;
            for I in 1 .. 5 loop
               if Button (To_String (Titles (I)), 384.0, YY, 668.0, HH => 38.0, Accent => True) then Choice := I; end if;
               Text (To_String (Descriptions (I)), 393.0, YY + 42.0, 12.0, Muted);
               YY := YY + 76.0;
            end loop;
            if Choice > 0 then
               Experiment (W, Choice, Selected);
               Notify (Ada.Strings.Fixed.Trim (W.Events (1).Text, Ada.Strings.Right));
               Modal := 0; Dirty := True;
            end if;
         elsif Modal = 2 then
            Text ("A field guide to Worldlines", 384.0, 246.0, 28.0, Ink, True);
            Text ("Observe first. Then ask what happens if...", 384.0, 289.0, 14.0, Mint);
            YY := 335.0;
            for I in Help_Text'Range loop
               Text (To_String (Help_Text (I)), 384.0, YY, (if I < 6 then 15.0 else 12.0), (if I < 6 then Ink else Muted));
               YY := YY + (if I < 6 then 34.0 else 31.0);
            end loop;
            Text ("Map boundaries: Natural Earth, public domain. Runtime: Ada 2022 + Raylib.", 384.0, 706.0, 12.0, Dim);
         elsif Modal = 3 then
            Text ("Begin another possible world", 384.0, 247.0, 28.0, Ink, True);
            Text ("The same seed creates the same starting world and autonomous decisions.", 384.0, 292.0, 14.0, Muted);
            Text ("Save your current world before replacing it.", 384.0, 319.0, 14.0, Gold);
            Text ("WORLD SEED  /  TYPE A NUMBER", 384.0, 374.0, 11.0, Muted, True);
            Box (384.0, 404.0, 668.0, 62.0, Background);
            Text (To_String (Seed_Input) & "_", 405.0, 417.0, 29.0, Mint, True);
            Key := GetCharPressed;
            while Key > 0 loop
               if Key >= 48 and Key <= 57 and Length (Seed_Input) < 8 then
                  Append (Seed_Input, Character'Val (Key));
               end if;
               Key := GetCharPressed;
            end loop;
            if Boolean (IsKeyPressed (KEY_BACKSPACE)) and Length (Seed_Input) > 0 then Delete (Seed_Input, Length (Seed_Input), Length (Seed_Input)); end if;
            if Button ("Generate world", 384.0, 503.0, 215.0, HH => 42.0, Accent => True) or Boolean (IsKeyPressed (KEY_ENTER)) then
               if Length (Seed_Input) = 0 then Seed_Input := To_Unbounded_String ("42"); end if;
               Initialize (W, Interfaces.Unsigned_32'Value (To_String (Seed_Input)));
               Paused := True; Dirty := True; Route_Month := -1; Accumulator := 0.0; Modal := 0;
               Notify ("A new world is ready. Press Play to watch it unfold.");
            end if;
            Text ("36 countries. Eight goods. Five technologies. Countless possible futures.", 384.0, 615.0, 15.0, Muted);
            Text ("No internet connection is needed to run the simulation.", 384.0, 646.0, 14.0, Dim);
         elsif Modal = 4 then
            Text ("The world dispatch", 384.0, 246.0, 28.0, Ink, True);
            Text ("Every event comes from a change in the model. Scroll to look back.", 384.0, 288.0, 14.0, Muted);
            Wheel := Float (GetMouseWheelMove);
            if Wheel > 0.0 and Event_Offset > 0 then Event_Offset := Event_Offset - 1; end if;
            if Wheel < 0.0 and Event_Offset + 6 < W.Event_Count then Event_Offset := Event_Offset + 1; end if;
            YY := 338.0;
            for Row in 1 .. 6 loop
               Event_Index := Event_Offset + Row;
               exit when Event_Index > W.Event_Count;
               Text (Date_Label (W.Events (Event_Index).Month), 384.0, YY, 12.0, Mint, True);
               Event_Text := To_Unbounded_String (Ada.Strings.Fixed.Trim (W.Events (Event_Index).Text, Ada.Strings.Right));
               if Length (Event_Text) > 87 then
                  Text (Slice (Event_Text, 1, 87), 475.0, YY, 12.0);
                  Text (Slice (Event_Text, 88, Length (Event_Text)), 475.0, YY + 18.0, 12.0, Muted);
               else
                  Text (To_String (Event_Text), 475.0, YY, 12.0);
               end if;
               if Within (384.0, YY, 669.0, 43.0) then
                  Hover_Button := True;
                  if Click and W.Events (Event_Index).Nation > 0 then
                     Selected := W.Events (Event_Index).Nation; Dirty := True; Modal := 0;
                  end if;
               end if;
               Rule (384.0, YY + 47.0, 669.0);
               YY := YY + 57.0;
            end loop;
            Text ("Showing " & Number (Float (Event_Offset + 1), 0) & " - " &
              Number (Float (Natural'Min (W.Event_Count, Event_Offset + 6)), 0) & " of " &
              Number (Float (W.Event_Count), 0) & " events. Click a national event to inspect its country.", 384.0, 706.0, 12.0, Muted);
         end if;
      end Draw_Modal;

      procedure Handle_Input is
         Wheel, Lon, Lat : Float;
         Hit : Natural;
      begin
         if Modal /= 0 then
            if IsKeyPressed (KEY_ESCAPE) then Modal := 0; end if;
            return;
         end if;
         if IsKeyPressed (KEY_SPACE) then Paused := not Paused; end if;
         if IsKeyPressed (KEY_RIGHT) then Step (W); Dirty := True; end if;
         if IsKeyPressed (KEY_ONE) then Speed := 1; end if;
         if IsKeyPressed (KEY_TWO) then Speed := 5; end if;
         if IsKeyPressed (KEY_THREE) then Speed := 20; end if;
         if IsKeyPressed (KEY_FOUR) then Speed := 100; end if;
         if IsKeyPressed (KEY_TAB) then Mode := (if Mode = Map_Mode'Last then Map_Mode'First else Map_Mode'Succ (Mode)); Dirty := True; end if;
         if IsKeyPressed (KEY_E) then Modal := 1; end if;
         if IsKeyPressed (KEY_H) then Modal := 2; end if;
         if IsKeyPressed (KEY_R) then Modal := 3; Seed_Input := To_Unbounded_String (Seed_Label); end if;
         if IsKeyPressed (KEY_F5) then Save (W, Save_Path, Ok); Notify ((if Ok then "Saved worldlines.sav" else "Could not save world.")); end if;
         if IsKeyPressed (KEY_F9) then
            Load (W, Save_Path, Ok); Dirty := True; Route_Month := -1;
            Notify ((if Ok then "World restored." else "No valid saved world found."));
         end if;
         if IsKeyPressed (KEY_S) then Export_CSV (W, CSV_Path, Ok); Notify ((if Ok then "Exported worldlines-export.csv" else "Could not export CSV.")); end if;
         if Within (Map_X, Map_Y, Map_W, Map_H) then
            Wheel := Float (GetMouseWheelMove);
            if Wheel /= 0.0 then Zoom := Float'Max (1.0, Float'Min (3.0, Zoom + Wheel * 0.15)); Dirty := True; end if;
            if IsMouseButtonDown (MOUSE_BUTTON_MIDDLE) then
               Pan_X := Float'Max (-Map_W * Zoom / 3.0, Float'Min (Map_W * Zoom / 3.0, Pan_X + Float (Mouse.X - Previous_Mouse.X)));
               Pan_Y := Float'Max (-Map_H * Zoom / 3.0, Float'Min (Map_H * Zoom / 3.0, Pan_Y + Float (Mouse.Y - Previous_Mouse.Y)));
               Dirty := True;
            end if;
            if Click and not Within (973.0, 647.0, 91.0, 27.0) then
               Lon := (Float (Mouse.X) - Map_X - Map_W / 2.0 - Pan_X) / (Map_W * Zoom) * 360.0;
               Lat := 82.0 - (Float (Mouse.Y) - Map_Y + (Zoom - 1.0) * Map_H / 2.0 - Pan_Y) / (Map_H * Zoom) * 145.0;
               Hit := World_Geography.Pick (Lon, Lat);
               if Hit > 0 then Selected := Hit; Dirty := True;
               else
                  for I in Country_Id loop
                     if CheckCollisionPointCircle (Mouse, Nation_Point (I), 8.0) then Selected := I; Dirty := True; exit; end if;
                  end loop;
               end if;
            end if;
         end if;
      end Handle_Input;

      procedure Screenshot (Path : String) is
         Shot : constant Image := LoadImageFromScreen;
         Written : Boolean;
      begin
         Written := Boolean (ExportImage (Shot, Path));
         UnloadImage (Shot);
         if not Written then raise Program_Error with "Could not export preview image"; end if;
      end Screenshot;

      procedure Smoke_Input is
         procedure Tap (X, Y : Float) is
         begin Mouse := V (X, Y); Click := True; end Tap;
      begin
         Mouse := V (-1.0, -1.0); Click := False; Down := False;
         case Frames is
            when 10 => Tap (1240.0, 248.0);
            when 12 => Mouse := V (1249.0, 378.0); Down := True;
            when 13 =>
               if not W.Nations (Selected).Manual_Policy or abs (W.Nations (Selected).Tariff - 0.30) > 0.01 then
                  raise Program_Error with "Policy slider input failed";
               end if;
            when 16 => Tap (1340.0, 248.0);
            when 17 => if Inspector_Tab /= 2 then raise Program_Error with "Research tab input failed"; end if;
            when 20 => Tap (205.0, 220.0);
            when 21 => if Mode /= Prosperity then raise Program_Error with "Map layer input failed"; end if;
            when 28 => Tap (318.0, 220.0);
            when 36 => Tap (439.0, 220.0);
            when 44 => Tap (553.0, 220.0);
            when 52 => Tap (670.0, 220.0);
            when 60 => Tap (540.0, 39.0);
            when 61 => if Modal /= 1 then raise Program_Error with "Experiments button failed"; end if;
            when 64 => Tap (650.0, 491.0);
            when 65 => if W.Energy_Shock_Months /= 24 then raise Program_Error with "Energy experiment input failed"; end if;
            when 66 => Tap (1058.0, 39.0);
            when 67 => if W.Energy_Shock_Months /= 23 then raise Program_Error with "Monthly step button failed"; end if;
            when 68 => Tap (730.0, 39.0);
            when 72 => Tap (1025.0, 255.0);
            when 76 => Tap (650.0, 39.0);
            when 80 => Tap (480.0, 523.0);
            when 81 => if W.Month /= 0 then raise Program_Error with "New world generation input failed"; end if;
            when 84 => Zoom := 2.0; Dirty := True;
            when 92 => Zoom := 1.0; Dirty := True; Mode := Trade; Selected := 19; Inspector_Tab := 0;
            when 96 => Tap (1058.0, 39.0);
            when 100 => Tap (1010.0, 747.0);
            when 101 => if Modal /= 4 then raise Program_Error with "Event history input failed"; end if;
            when 106 => Tap (1025.0, 255.0);
            when others => null;
         end case;
      end Smoke_Input;

   begin
      World_Geography.Load (Assets & "/world.map");
      if Smoke_Test and then
        (World_Geography.Pick (-52.0, -12.0) /= 4 or World_Geography.Pick (104.0, 35.0) /= 19 or
         World_Geography.Pick (-30.0, 0.0) /= 0) then
         raise Program_Error with "Country polygon hit testing failed";
      end if;
      SetConfigFlags (FLAG_WINDOW_RESIZABLE or FLAG_MSAA_4X_HINT);
      InitWindow (1440, 900, "Worldlines | World Trade Simulator");
      SetWindowMinSize (960, 600);
      SetExitKey (KEY_NULL);
      SetTargetFPS (60);
      if Ada.Directories.Exists ("C:/Windows/Fonts/segoeui.ttf") then
         Font_Normal := LoadFontEx ("C:/Windows/Fonts/segoeui.ttf", 32, null, 0);
         Font_Bold := LoadFontEx ("C:/Windows/Fonts/segoeuib.ttf", 40, null, 0);
         Font_Title := LoadFontEx ("C:/Windows/Fonts/georgia.ttf", 48, null, 0);
      else
         Font_Normal := GetFontDefault; Font_Bold := Font_Normal; Font_Title := Font_Normal;
      end if;
      SetTextureFilter (Font_Normal.Texture_F, TEXTURE_FILTER_BILINEAR);
      SetTextureFilter (Font_Bold.Texture_F, TEXTURE_FILTER_BILINEAR);
      SetTextureFilter (Font_Title.Texture_F, TEXTURE_FILTER_BILINEAR);
      Canvas := LoadRenderTexture (1440, 900);
      Map_Cache := LoadRenderTexture (1440, 900);
      SetTextureFilter (Canvas.Texture_F, TEXTURE_FILTER_BILINEAR);
      if Capture /= "" then for M in 1 .. 60 loop Step (W); end loop; end if;
      while not WindowShouldClose loop
         Frames := Frames + 1;
         Scale := Float'Min (Float (GetScreenWidth) / Width, Float (GetScreenHeight) / Height);
         Screen_X := (Float (GetScreenWidth) - Width * Scale) / 2.0;
         Screen_Y := (Float (GetScreenHeight) - Height * Scale) / 2.0;
         Previous_Mouse := Mouse;
         Mouse := V ((Float (GetMouseX) - Screen_X) / Scale, (Float (GetMouseY) - Screen_Y) / Scale);
         Click := Boolean (IsMouseButtonPressed (MOUSE_BUTTON_LEFT));
         Down := Boolean (IsMouseButtonDown (MOUSE_BUTTON_LEFT));
         Hover_Button := False;
         if Smoke_Test then Smoke_Input; end if;
         Handle_Input;
         if not Paused and Modal = 0 then
            Accumulator := Accumulator + Float (GetFrameTime) * Float (Speed);
            for Limit in 1 .. 16 loop
               exit when Accumulator < 0.65;
               Step (W); Dirty := True; Accumulator := Accumulator - 0.65;
            end loop;
         end if;
         Status_Time := Float'Max (0.0, Status_Time - Float (GetFrameTime));
         if Dirty then Build_Map; end if;
         BeginTextureMode (Canvas);
         ClearBackground (Background);
         --  Map cache has transparent margins and can be drawn over the complete interface.
         Draw_Map;
         Draw_Header;
         Draw_Inspector;
         Draw_Markets;
         Draw_Feed;
         Rule (28.0, 870.0, 1384.0);
         if Status_Time > 0.0 then
            Text (To_String (Status), 32.0, 879.0, 11.0, Mint);
         else
            Text ("SPACE  Play / pause     RIGHT  One month     E  Experiments     H  Field guide", 32.0, 879.0, 11.0, Dim);
            Text ("MADE WITH NATURAL EARTH  /  ADA 2022", 1128.0, 879.0, 10.0, Dim);
         end if;
         if Modal /= 0 then Draw_Modal; end if;
         EndTextureMode;
         BeginDrawing;
         ClearBackground (Background);
         DrawTexturePro (Canvas.Texture_F, R (0.0, 0.0, Width, -Height),
           R (Screen_X, Screen_Y, Width * Scale, Height * Scale), V (0.0, 0.0), 0.0, RGB (255, 255, 255));
         EndDrawing;
         SetMouseCursor (int (MouseCursor'Pos (if Hover_Button then MOUSE_CURSOR_POINTING_HAND else MOUSE_CURSOR_DEFAULT)));
         if Capture /= "" and Frames = 6 then Screenshot (Capture); end if;
         if Capture /= "" and not Smoke_Test and Frames >= 8 then exit; end if;
         if Smoke_Test then
            if Capture /= "" then
               case Frames is
                  when 14 => Screenshot (Capture & ".policies.png");
                  when 18 => Screenshot (Capture & ".research.png");
                  when 22 => Screenshot (Capture & ".prosperity.png");
                  when 62 => Screenshot (Capture & ".experiments.png");
                  when 70 => Screenshot (Capture & ".help.png");
                  when 78 => Screenshot (Capture & ".new-world.png");
                  when 104 => Screenshot (Capture & ".dispatch.png");
                  when others => null;
               end case;
            end if;
            if Frames >= 110 then
               Ada.Text_IO.Put_Line ("PASS  graphical rendering, polygon selection, policy slider, research tab, map layers, experiment, monthly step, new world and event history");
               exit;
            end if;
         end if;
      end loop;
      UnloadRenderTexture (Map_Cache);
      UnloadRenderTexture (Canvas);
      if Ada.Directories.Exists ("C:/Windows/Fonts/segoeui.ttf") then
         UnloadFont (Font_Normal); UnloadFont (Font_Bold); UnloadFont (Font_Title);
      end if;
      CloseWindow;
   end Run;
end Worldlines_UI;
