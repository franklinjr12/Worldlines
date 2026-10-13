with Interfaces;

package Economy is
   pragma Style_Checks (Off);
   Country_Count : constant := 36;
   subtype Country_Id is Positive range 1 .. Country_Count;
   type Good is (Food, Energy, Minerals, Metals, Machinery, Electronics,
                 Consumer_Goods, Services);
   type Technology is (Agriculture, Extraction, Manufacturing, Advanced, Logistics);
   type Philosophy is (Prosperity_First, Industrialist, Open_Markets, Knowledge_First);
   type Goods_Array is array (Good) of Float;
   type Tech_Array is array (Technology) of Float;
   type History_Array is array (0 .. 119) of Float;
   type Country is record
      Name : String (1 .. 24) := [others => ' '];
      ISO : String (1 .. 3) := "---";
      Longitude, Latitude : Float := 0.0;
      Population, Capital, GDP, Growth : Float := 0.0;
      Prosperity : Float := 50.0;
      Infrastructure : Float := 4.0;
      Landlocked : Boolean := False;
      Bloc : Natural range 0 .. 5 := 0;
      Priority : Philosophy := Prosperity_First;
      Tariff : Float := 0.08;
      Industry_Budget : Float := 0.35;
      Research_Budget : Float := 0.25;
      Infrastructure_Budget : Float := 0.20;
      Manual_Policy : Boolean := False;
      Resources : Goods_Array := [others => 1.0];
      Capacity, Stock, Output, Demand, Prices : Goods_Array := [others => 0.0];
      Imports, Exports : Goods_Array := [others => 0.0];
      Tech : Tech_Array := [others => 4.0];
      GDP_History, Prosperity_History : History_Array := [others => 0.0];
      Last_Investment : Good := Food;
      Shortage : Float := 0.0;
   end record;
   type Country_Array is array (Country_Id) of Country;
   type Relation_Array is array (Country_Id, Country_Id) of Float;
   type Trade_Route is record
      Seller, Buyer : Country_Id := 1;
      Product : Good := Food;
      Quantity, Value : Float := 0.0;
   end record;
   Max_Routes : constant := 4096;
   type Route_Array is array (1 .. Max_Routes) of Trade_Route;
   type Event_Record is record
      Month : Natural := 0;
      Nation : Natural range 0 .. Country_Count := 0;
      Text : String (1 .. 160) := [others => ' '];
   end record;
   type Event_Array is array (1 .. 60) of Event_Record;
   type World_State is record
      Nations : Country_Array;
      Relations : Relation_Array := [others => [others => 0.0]];
      Routes : Route_Array;
      Route_Count : Natural range 0 .. Max_Routes := 0;
      Events : Event_Array;
      Event_Count : Natural range 0 .. 60 := 0;
      Month : Natural := 0;
      Seed : Interfaces.Unsigned_32 := 42;
      Random_State : Interfaces.Unsigned_32 := 42;
      World_Prices : Goods_Array := [others => 1.0];
      Global_GDP, Global_Trade, Trade_Friction : Float := 0.0;
      Energy_Shock_Months : Natural := 0;
      Energy_Shock_Factor : Float := 1.0;
      Last_Trade_Balance_Error : Float := 0.0;
   end record;
   Base_Prices : constant Goods_Array :=
     [0.65, 1.10, 0.70, 1.40, 2.60, 4.20, 1.70, 1.10];
   procedure Initialize (W : out World_State; Seed : Interfaces.Unsigned_32 := 42);
   procedure Step (W : in out World_State);
   procedure Experiment (W : in out World_State; Choice : Positive; Nation : Country_Id);
   procedure Add_Event (W : in out World_State; Text : String; Nation : Natural := 0);
   function Name_Of (C : Country) return String;
   function Good_Name (G : Good) return String;
   function Tech_Name (T : Technology) return String;
   function Priority_Name (P : Philosophy) return String;
   function Bloc_Name (B : Natural) return String;
   function Date_Label (Month : Natural) return String;
   function Number (V : Float; Decimals : Natural := 1) return String;
   function Money (V : Float) return String;
   function Average_Tech (C : Country) return Float;
   function Main_Export (C : Country) return Good;
   function Transport_Cost (A, B : Country) return Float;
   function Valid (W : World_State) return Boolean;
   procedure Save (W : World_State; Path : String; Success : out Boolean);
   procedure Load (W : in out World_State; Path : String; Success : out Boolean);
   procedure Export_CSV (W : World_State; Path : String; Success : out Boolean);
end Economy;
