with Ada.Text_IO;
with Ada.Float_Text_IO;
with Ada.Strings.Fixed;
with Ada.Strings;
with Ada.Numerics.Elementary_Functions;
with Ada.Streams.Stream_IO;
with Starting_World;

package body Economy is
   pragma Style_Checks (Off);
   use Ada.Numerics.Elementary_Functions;
   use type Interfaces.Unsigned_32;

   function Clamp (X, Low, High : Float) return Float is
     (Float'Max (Low, Float'Min (High, X)));

   function Number (V : Float; Decimals : Natural := 1) return String is
      S : String (1 .. 40);
   begin
      if Decimals = 0 then
         return Ada.Strings.Fixed.Trim (Long_Long_Integer'Image (Long_Long_Integer (V)), Ada.Strings.Both);
      end if;
      Ada.Float_Text_IO.Put (S, V, Aft => Decimals, Exp => 0);
      return Ada.Strings.Fixed.Trim (S, Ada.Strings.Both);
   end Number;

   function Money (V : Float) return String is
     (if abs V >= 1000.0 then "$" & Number (V / 1000.0, 2) & "T"
      else "$" & Number (V, 1) & "B");
   function Name_Of (C : Country) return String is
     (Ada.Strings.Fixed.Trim (C.Name, Ada.Strings.Right));
   function Good_Name (G : Good) return String is
   begin
      case G is
         when Food => return "Food";
         when Energy => return "Energy";
         when Minerals => return "Minerals";
         when Metals => return "Metals";
         when Machinery => return "Machinery";
         when Electronics => return "Electronics";
         when Consumer_Goods => return "Consumer goods";
         when Services => return "Services";
      end case;
   end Good_Name;
   function Tech_Name (T : Technology) return String is
   begin
      case T is
         when Agriculture => return "Agriculture";
         when Extraction => return "Extraction";
         when Manufacturing => return "Manufacturing";
         when Advanced => return "Advanced industry";
         when Logistics => return "Logistics";
      end case;
   end Tech_Name;
   function Priority_Name (P : Philosophy) return String is
   begin
      case P is
         when Prosperity_First => return "Citizen prosperity";
         when Industrialist => return "Industrial self-reliance";
         when Open_Markets => return "Open markets";
         when Knowledge_First => return "Technology leadership";
      end case;
   end Priority_Name;
   function Bloc_Name (B : Natural) return String is
   begin
      case B is
         when 1 => return "North American pact";
         when 2 => return "European common market";
         when 3 => return "South American pact";
         when 4 => return "Asia-Pacific network";
         when 5 => return "African common market";
         when others => return "Independent economy";
      end case;
   end Bloc_Name;
   function Date_Label (Month : Natural) return String is
      Names : constant array (0 .. 11) of String (1 .. 3) :=
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
   begin
      return Names (Month mod 12) & " " &
        Ada.Strings.Fixed.Trim (Integer'Image (2025 + Month / 12), Ada.Strings.Both);
   end Date_Label;
   function Average_Tech (C : Country) return Float is
      Sum : Float := 0.0;
   begin
      for T in Technology loop Sum := Sum + C.Tech (T); end loop;
      return Sum / 5.0;
   end Average_Tech;
   function Main_Export (C : Country) return Good is
      Best : Good := Food;
   begin
      for G in Good loop
         if C.Exports (G) > C.Exports (Best) then Best := G; end if;
      end loop;
      return Best;
   end Main_Export;

   function Random (W : in out World_State) return Float is
   begin
      W.Random_State := W.Random_State * 1664525 + 1013904223;
      return Float (W.Random_State mod 1000000) / 1000000.0;
   end Random;

   procedure Add_Event (W : in out World_State; Text : String; Nation : Natural := 0) is
   begin
      for I in reverse 2 .. 60 loop W.Events (I) := W.Events (I - 1); end loop;
      W.Events (1) := (Month => W.Month, Nation => Nation, Text => [others => ' ']);
      W.Events (1).Text (1 .. Integer'Min (160, Text'Length)) :=
        Text (Text'First .. Text'First + Integer'Min (160, Text'Length) - 1);
      W.Event_Count := Natural'Min (60, W.Event_Count + 1);
   end Add_Event;

   procedure Initialize (W : out World_State; Seed : Interfaces.Unsigned_32 := 42) is
      Dev, Scale, Jitter : Float;
   begin
      W := (others => <>);
      W.Seed := Seed;
      W.Random_State := Seed;
      Starting_World.Populate (W.Nations);
      for C of W.Nations loop
         Dev := Average_Tech (C) / 5.0;
         Scale := C.Population;
         for G in Good loop
            Jitter := 0.94 + 0.12 * Random (W);
            C.Capacity (G) := Scale * Jitter *
              (case G is
                 when Food => 0.085 * C.Resources (Food),
                 when Energy => 0.085 * C.Resources (Energy),
                 when Minerals => 0.035 * C.Resources (Minerals),
                 when Metals => 0.052 * Dev,
                 when Machinery => 0.018 * Dev * Dev,
                 when Electronics => 0.010 * Dev * Dev,
                 when Consumer_Goods => 0.041 * Dev,
                 when Services => 0.100 * Dev);
            C.Prices (G) := Base_Prices (G);
            C.Stock (G) := C.Capacity (G) * 2.0 + C.Population * 0.06;
         end loop;
         C.Capital := C.Population * Dev * 3.0;
         C.GDP := C.Population * Dev * 6.0;
         C.GDP_History := [others => C.GDP];
         C.Prosperity_History := [others => C.Prosperity];
      end loop;
      for A in Country_Id loop
         for B in Country_Id loop
            W.Relations (A, B) :=
              (if W.Nations (A).Bloc /= 0 and W.Nations (A).Bloc = W.Nations (B).Bloc
               then 45.0 else 10.0);
         end loop;
      end loop;
      W.World_Prices := Base_Prices;
      Add_Event (W, "A new world begins. Select a country and follow its economy.");
      --  Establish one market cycle without advancing the starting date.
      Step (W);
      W.Month := 0;
      W.Events (1).Month := 0;
      for C of W.Nations loop
         C.GDP_History := [others => C.GDP];
         C.Prosperity_History := [others => C.Prosperity];
         C.Growth := 0.0;
      end loop;
   end Initialize;

   function Transport_Cost (A, B : Country) return Float is
      Lat1 : constant Float := A.Latitude * 0.017453293;
      Lat2 : constant Float := B.Latitude * 0.017453293;
      DLat : constant Float := (A.Latitude - B.Latitude) * 0.017453293;
      DLon : constant Float := (A.Longitude - B.Longitude) * 0.017453293;
      H : constant Float := Clamp (Sin (DLat / 2.0) ** 2 +
        Cos (Lat1) * Cos (Lat2) * Sin (DLon / 2.0) ** 2, 0.0, 1.0);
      Distance : constant Float := 2.0 * 6371.0 * Arcsin (Sqrt (H));
   begin
      return (0.025 + Distance / 40000.0 +
        (if A.Landlocked or B.Landlocked then 0.08 else 0.0)) /
        (0.7 + (A.Infrastructure + B.Infrastructure +
         A.Tech (Logistics) + B.Tech (Logistics)) / 28.0);
   end Transport_Cost;

   procedure Step (W : in out World_State) is
      type Nation_Goods is array (Country_Id) of Goods_Array;
      Target : Nation_Goods;
      Previous_GDP : array (Country_Id) of Float;
      Previous_Price : constant Goods_Array := W.World_Prices;
      type Recipe_Matrix is array (Good) of Goods_Array;
      Recipes : constant Recipe_Matrix :=
        [Metals => [Minerals => 0.72, Energy => 0.30, others => 0.0],
         Machinery => [Metals => 0.58, Energy => 0.24, others => 0.0],
         Electronics => [Metals => 0.32, Machinery => 0.22, Energy => 0.20, others => 0.0],
         Consumer_Goods => [Machinery => 0.09, Energy => 0.18, Metals => 0.08, others => 0.0],
         others => [others => 0.0]];
      Before_Trade, After_Trade : Float := 0.0;
      Efficiency, Amount, Input_Cost, Value_Added, Need, Available : Float;
      Best_Cost, Delivered, Surplus, Quantity, Bill, Revenue, Friction : Float;
      Fulfillment, Income_Factor, Budget, Score, Best_Score, Investment : Float;
      Allocation_Divisor : Float;
      Best_Seller : Natural;
      Best_Sector : Good;
      Offset : constant Natural := Natural (Random (W) * Float (Country_Count - 1));
      Buyer : Country_Id;
   begin
      W.Month := W.Month + 1;
      W.Route_Count := 0;
      W.Global_Trade := 0.0;
      W.Trade_Friction := 0.0;
      W.Global_GDP := 0.0;
      for I in Country_Id loop
         declare C : Country renames W.Nations (I); begin
            Previous_GDP (I) := C.GDP;
            C.Output := [others => 0.0];
            C.Imports := [others => 0.0];
            C.Exports := [others => 0.0];
            C.Demand := [others => 0.0];
            Value_Added := 0.0;
            Income_Factor := 0.65 + C.Prosperity / 120.0;
            C.Demand (Food) := C.Population * 0.10;
            C.Demand (Energy) := C.Population * 0.045 * Income_Factor;
            C.Demand (Consumer_Goods) := C.Population * 0.043 * Income_Factor;
            C.Demand (Electronics) := C.Population * 0.008 * Income_Factor;
            C.Demand (Services) := C.Population * 0.085 * Income_Factor;
            for G in Good loop
               C.Stock (G) := C.Stock (G) * (if G = Food then 0.92 elsif G = Services then 0.30 else 0.98);
               Efficiency := 0.65 + C.Tech
                 ((case G is when Food => Agriculture, when Energy | Minerals => Extraction,
                   when Electronics => Advanced, when Services => Advanced, when others => Manufacturing)) / 12.0;
               Amount := C.Capacity (G) * Efficiency * (0.88 + C.Infrastructure / 45.0);
               if G = Energy and W.Energy_Shock_Months > 0 then
                  Amount := Amount * W.Energy_Shock_Factor;
               end if;
               --  Inputs must exist before any downstream output can be made.
               for Input in Good loop
                  if Recipes (G) (Input) > 0.0 then
                     Amount := Float'Min (Amount, C.Stock (Input) /
                       (Recipes (G) (Input) * (1.15 - C.Tech (Manufacturing) / 35.0)));
                  end if;
               end loop;
               Input_Cost := 0.0;
               for Input in Good loop
                  Need := Amount * Recipes (G) (Input) * (1.15 - C.Tech (Manufacturing) / 35.0);
                  C.Stock (Input) := Float'Max (0.0, C.Stock (Input) - Need);
                  Input_Cost := Input_Cost + Need * Base_Prices (Input);
               end loop;
               C.Output (G) := Amount;
               C.Stock (G) := C.Stock (G) + Amount;
               Value_Added := Value_Added + Float'Max (0.0, Amount * Base_Prices (G) - Input_Cost);
            end loop;
            C.GDP := Value_Added * 12.0;
            --  Retained domestic value added provides finite investment/import capital.
            C.Capital := C.Capital + Value_Added * 0.12;
            for G in Good loop
               Target (I) (G) := C.Demand (G) * 1.4;
               for Sector in Good loop
                  Target (I) (G) := Target (I) (G) + C.Capacity (Sector) * Recipes (Sector) (G) * 1.3;
               end loop;
               Target (I) (G) := Float'Max (Target (I) (G), C.Capacity (G) * 0.22);
               C.Prices (G) := Clamp (C.Prices (G) * 0.78 + 0.22 * Base_Prices (G) *
                 Clamp ((Target (I) (G) + 0.05) / (C.Stock (G) + 0.05), 0.30, 4.5),
                 Base_Prices (G) * 0.30, Base_Prices (G) * 4.5);
            end loop;
            Before_Trade := Before_Trade + C.Capital;
         end;
      end loop;
      --  Buyers choose the cheapest affordable delivered offer, without creating goods or money.
      for G in Good loop
         if G /= Services then
            for Position in Country_Id loop
               Buyer := Country_Id ((Position + Offset - 1) mod Country_Count + 1);
               for Attempt in 1 .. 8 loop
                  Need := Target (Buyer) (G) - W.Nations (Buyer).Stock (G);
                  exit when Need < 0.001 or W.Nations (Buyer).Capital < 0.01;
                  Best_Seller := 0;
                  Best_Cost := W.Nations (Buyer).Prices (G) * 1.6;
                  for Seller in Country_Id loop
                     if Seller /= Buyer then
                        Surplus := W.Nations (Seller).Stock (G) - Target (Seller) (G) * 1.1;
                        if Surplus > 0.001 then
                           Delivered := W.Nations (Seller).Prices (G) *
                             (1.0 + Transport_Cost (W.Nations (Seller), W.Nations (Buyer)) +
                              W.Nations (Buyer).Tariff *
                              (if W.Nations (Buyer).Bloc /= 0 and
                               W.Nations (Buyer).Bloc = W.Nations (Seller).Bloc then 0.15 else 1.0) +
                              Float'Max (0.0, -W.Relations (Seller, Buyer)) / 500.0);
                           if Delivered < Best_Cost then
                              Best_Cost := Delivered;
                              Best_Seller := Seller;
                           end if;
                        end if;
                     end if;
                  end loop;
                  exit when Best_Seller = 0;
                  Surplus := W.Nations (Best_Seller).Stock (G) - Target (Best_Seller) (G) * 1.1;
                  Quantity := Float'Min (Need, Float'Min (Surplus,
                    W.Nations (Buyer).Capital * 0.06 / Best_Cost));
                  exit when Quantity < 0.001;
                  Revenue := Quantity * W.Nations (Best_Seller).Prices (G);
                  Bill := Quantity * Best_Cost;
                  Friction := Bill - Revenue;
                  W.Nations (Buyer).Stock (G) := W.Nations (Buyer).Stock (G) + Quantity;
                  W.Nations (Best_Seller).Stock (G) := W.Nations (Best_Seller).Stock (G) - Quantity;
                  W.Nations (Buyer).Capital := W.Nations (Buyer).Capital - Bill;
                  W.Nations (Best_Seller).Capital := W.Nations (Best_Seller).Capital + Revenue;
                  W.Nations (Buyer).Imports (G) := W.Nations (Buyer).Imports (G) + Bill;
                  W.Nations (Best_Seller).Exports (G) := W.Nations (Best_Seller).Exports (G) + Revenue;
                  W.Global_Trade := W.Global_Trade + Revenue;
                  W.Trade_Friction := W.Trade_Friction + Friction;
                  W.Relations (Best_Seller, Buyer) := Clamp (W.Relations (Best_Seller, Buyer) + 0.03, -100.0, 100.0);
                  W.Relations (Buyer, Best_Seller) := W.Relations (Best_Seller, Buyer);
                  --  Trading partners transfer productive knowledge gradually.
                  for T in Technology loop
                     W.Nations (Buyer).Tech (T) := W.Nations (Buyer).Tech (T) +
                       Float'Max (0.0, W.Nations (Best_Seller).Tech (T) - W.Nations (Buyer).Tech (T)) * 0.00025;
                  end loop;
                  if W.Route_Count < Max_Routes then
                     W.Route_Count := W.Route_Count + 1;
                     W.Routes (W.Route_Count) :=
                       (Country_Id (Best_Seller), Buyer, G, Quantity, Revenue);
                  end if;
               end loop;
            end loop;
         end if;
      end loop;
      for C of W.Nations loop After_Trade := After_Trade + C.Capital; end loop;
      W.Last_Trade_Balance_Error := abs (Before_Trade - After_Trade - W.Trade_Friction);
      W.World_Prices := [others => 0.0];
      for I in Country_Id loop
         declare C : Country renames W.Nations (I); begin
            Fulfillment := 0.0;
            for G in Good loop
               if C.Demand (G) > 0.0 then
                  Available := Float'Min (C.Stock (G), C.Demand (G));
                  Fulfillment := Fulfillment + Available / C.Demand (G);
                  C.Stock (G) := C.Stock (G) - Available;
               end if;
               --  Finite storage prevents perpetual surplus accumulation.
               C.Stock (G) := Float'Min (C.Stock (G), Float'Max (0.1, Target (I) (G) * 6.0));
               W.World_Prices (G) := W.World_Prices (G) + C.Prices (G) / Float (Country_Count);
            end loop;
            C.Shortage := 1.0 - Fulfillment / 5.0;
            C.Prosperity := Clamp (C.Prosperity * 0.94 + 0.06 *
              (Fulfillment / 5.0 * 65.0 + Average_Tech (C) * 3.5), 0.0, 100.0);
            C.Population := C.Population * (1.0 + 0.0003 * (C.Prosperity / 50.0 - 0.5));
            C.Growth := (C.GDP / Float'Max (0.01, Previous_GDP (I)) - 1.0) * 100.0;
            if not C.Manual_Policy and W.Month mod 12 = 0 then
               C.Tariff := Clamp (C.Tariff + (if C.Priority = Industrialist and C.Shortage < 0.2
                 then 0.01 elsif C.Shortage > 0.15 then -0.015 else 0.0), 0.0, 0.45);
            end if;
            Budget := Float'Min (C.Capital * 0.014, C.GDP / 12.0 * 0.24);
            Allocation_Divisor := Float'Max (1.0,
              C.Industry_Budget + C.Research_Budget + C.Infrastructure_Budget);
            Best_Score := -1.0;
            Best_Sector := Food;
            for G in Good loop
               Score := C.Prices (G) / Base_Prices (G) *
                 (0.65 + C.Resources (G) * 0.35) * (0.85 + 0.30 * Random (W));
               if C.Priority = Industrialist and G in Metals .. Consumer_Goods then Score := Score * 1.3; end if;
               if C.Priority = Prosperity_First and G in Food | Services then Score := Score * 1.25; end if;
               if C.Priority = Knowledge_First and G = Electronics then Score := Score * 1.4; end if;
               if Score > Best_Score then Best_Score := Score; Best_Sector := G; end if;
            end loop;
            Investment := Budget * C.Industry_Budget / Allocation_Divisor;
            --  Capital AND machinery are necessary for productive expansion.
            Amount := Float'Min (Investment / (Base_Prices (Best_Sector) * 14.0), C.Stock (Machinery) / 0.12);
            C.Capacity (Best_Sector) := C.Capacity (Best_Sector) + Amount;
            C.Stock (Machinery) := Float'Max (0.0, C.Stock (Machinery) - Amount * 0.12);
            for G in Good loop C.Capacity (G) := C.Capacity (G) * 0.9992; end loop;
            C.Last_Investment := Best_Sector;
            for T in Technology loop
               C.Tech (T) := Clamp (C.Tech (T) + Budget * C.Research_Budget / Allocation_Divisor /
                 Float'Max (1.0, C.Population) * 0.18 * (1.0 - C.Tech (T) / 11.0) *
                 (if T = Advanced then C.Tech (Manufacturing) / 8.0 else 1.0), 1.0, 10.0);
            end loop;
            C.Infrastructure := Clamp (C.Infrastructure + Budget * C.Infrastructure_Budget / Allocation_Divisor /
              Float'Max (1.0, C.Population) * 0.12, 1.0, 10.0);
            C.Capital := Float'Max (0.0, C.Capital -
              (Amount * Base_Prices (Best_Sector) * 14.0 + Budget *
               (C.Research_Budget + C.Infrastructure_Budget) / Allocation_Divisor));
            C.GDP_History (W.Month mod 120) := C.GDP;
            C.Prosperity_History (W.Month mod 120) := C.Prosperity;
            W.Global_GDP := W.Global_GDP + C.GDP;
            if W.Month mod 24 = 0 and I = Country_Id ((W.Month / 24 - 1) mod Country_Count + 1) then
               Add_Event (W, Name_Of (C) & " directs investment toward " & Good_Name (Best_Sector) &
                 ". Local price: " & Number (C.Prices (Best_Sector) / Base_Prices (Best_Sector), 2) & "x baseline.", I);
            end if;
         end;
      end loop;
      if W.Month mod 12 = 0 then
         declare Best : Country_Id := 1; begin
            for I in Country_Id loop
               if W.Nations (I).Shortage > W.Nations (Best).Shortage then Best := I; end if;
            end loop;
            if W.Nations (Best).Shortage > 0.10 then
               Add_Event (W, Name_Of (W.Nations (Best)) & " meets " &
                 Number ((1.0 - W.Nations (Best).Shortage) * 100.0, 0) &
                 "% of household demand. Missing inputs constrain its economy.", Best);
            else
               Add_Event (W, "World trade reaches " & Money (W.Global_Trade * 12.0) &
                 " annualized across " & Number (Float (W.Route_Count), 0) & " shipments.");
            end if;
         end;
      end if;
      for G in Good loop
         if W.World_Prices (G) > Previous_Price (G) * 1.08 and W.Month > 6 then
            Add_Event (W, Good_Name (G) & " prices rise " &
              Number ((W.World_Prices (G) / Previous_Price (G) - 1.0) * 100.0, 0) &
              "% this month as inventories tighten.");
         end if;
      end loop;
      if W.Energy_Shock_Months > 0 then
         W.Energy_Shock_Months := W.Energy_Shock_Months - 1;
         if W.Energy_Shock_Months = 0 then Add_Event (W, "Energy extraction recovers. Inventories and prices will take time to adjust."); end if;
      end if;
   end Step;

   procedure Experiment (W : in out World_State; Choice : Positive; Nation : Country_Id) is
   begin
      case Choice is
         when 1 =>
            W.Nations (Nation).Industry_Budget := 0.65;
            W.Nations (Nation).Research_Budget := 0.45;
            W.Nations (Nation).Manual_Policy := True;
            Add_Event (W, Name_Of (W.Nations (Nation)) & " launches an industrial investment and research program.", Nation);
         when 2 =>
            for C of W.Nations loop C.Tariff := 0.40; C.Manual_Policy := True; end loop;
            Add_Event (W, "Global tariff experiment: all economies set import tariffs to 40%.");
         when 3 =>
            W.Energy_Shock_Months := 24;
            W.Energy_Shock_Factor := 0.45;
            Add_Event (W, "Energy shock: world extraction falls 55% for 24 months. Follow downstream shortages.");
         when 4 =>
            for C of W.Nations loop if C.Bloc = 5 then C.Tariff := 0.0; C.Manual_Policy := True; end if; end loop;
            Add_Event (W, "African free-trade experiment: member economies eliminate import tariffs.");
         when 5 =>
            W.Nations (Nation).Tech (Manufacturing) := Float'Min (10.0, W.Nations (Nation).Tech (Manufacturing) + 2.0);
            Add_Event (W, Name_Of (W.Nations (Nation)) & " gains two manufacturing technology levels. Inputs become more efficient.", Nation);
         when others => null;
      end case;
   end Experiment;

   function Valid (W : World_State) return Boolean is
   begin
      if W.Month > 120000 or W.Energy_Shock_Months > 120000 then return False; end if;
      if not (W.Energy_Shock_Factor in 0.0 .. 1.0) then return False; end if;
      if not (W.Global_GDP in 0.0 .. 1.0E10 and W.Global_Trade in 0.0 .. 1.0E10 and
        W.Trade_Friction in 0.0 .. 1.0E10) then return False; end if;
      for C of W.Nations loop
         if not (C.Population in 0.01 .. 100000.0 and C.Capital in 0.0 .. 1.0E10 and
           C.GDP in 0.0 .. 1.0E10 and C.Prosperity in 0.0 .. 100.0 and
           C.Tariff in 0.0 .. 0.60 and C.Infrastructure in 1.0 .. 10.0 and
           C.Longitude in -180.0 .. 180.0 and C.Latitude in -90.0 .. 90.0 and
           C.Industry_Budget in 0.0 .. 1.0 and C.Research_Budget in 0.0 .. 1.0 and
           C.Infrastructure_Budget in 0.0 .. 1.0 and C.Shortage in -0.0001 .. 1.0001) then return False; end if;
         for G in Good loop
            if not (C.Stock (G) in 0.0 .. 1.0E10 and C.Capacity (G) in 0.0 .. 1.0E10 and
              C.Prices (G) in Base_Prices (G) * 0.29 .. Base_Prices (G) * 4.51 and
              C.Resources (G) in 0.0 .. 10.0 and C.Output (G) in 0.0 .. 1.0E10 and
              C.Imports (G) in 0.0 .. 1.0E10 and C.Exports (G) in 0.0 .. 1.0E10) then return False; end if;
         end loop;
         for T in Technology loop if not (C.Tech (T) in 1.0 .. 10.0) then return False; end if; end loop;
         for V of C.GDP_History loop if not (V in 0.0 .. 1.0E10) then return False; end if; end loop;
         for V of C.Prosperity_History loop if not (V in 0.0 .. 100.0) then return False; end if; end loop;
      end loop;
      for Row of W.Relations loop if not (Row in -100.0 .. 100.0) then return False; end if; end loop;
      return True;
   end Valid;

   procedure Save (W : World_State; Path : String; Success : out Boolean) is
      use Ada.Streams.Stream_IO;
      F : File_Type;
   begin
      Success := False;
      Create (F, Out_File, Path);
      String'Write (Stream (F), "WORLDLINES-01");
      World_State'Write (Stream (F), W);
      Close (F);
      Success := True;
   exception when others => if Is_Open (F) then Close (F); end if;
   end Save;
   procedure Load (W : in out World_State; Path : String; Success : out Boolean) is
      use Ada.Streams.Stream_IO;
      F : File_Type;
      Header : String (1 .. 13);
      Candidate : World_State;
   begin
      Success := False;
      Open (F, In_File, Path);
      String'Read (Stream (F), Header);
      if Header = "WORLDLINES-01" then
         World_State'Read (Stream (F), Candidate);
         if Valid (Candidate) then W := Candidate; Success := True; end if;
      end if;
      Close (F);
   exception when others => if Is_Open (F) then Close (F); end if;
   end Load;
   procedure Export_CSV (W : World_State; Path : String; Success : out Boolean) is
      F : Ada.Text_IO.File_Type;
   begin
      Success := False;
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (F, "date,iso,country,population_millions,real_gdp_billions,capital_billions,prosperity,technology,tariff,main_export");
      for C of W.Nations loop
         Ada.Text_IO.Put_Line (F, Date_Label (W.Month) & "," & C.ISO & "," & Name_Of (C) & "," &
           Number (C.Population, 3) & "," & Number (C.GDP, 3) & "," & Number (C.Capital, 3) & "," &
           Number (C.Prosperity, 2) & "," & Number (Average_Tech (C), 3) & "," & Number (C.Tariff, 3) & "," & Good_Name (Main_Export (C)));
      end loop;
      Ada.Text_IO.Close (F);
      Success := True;
   exception when others => if Ada.Text_IO.Is_Open (F) then Ada.Text_IO.Close (F); end if;
   end Export_CSV;
end Economy;
