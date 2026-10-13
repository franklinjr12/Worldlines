// Build-time conversion only. The delivered app and simulation are entirely Ada.
const fs = require('fs');
const path = require('path');
const root = path.basename(__dirname) === 'tools' ? path.resolve(__dirname, '..') : __dirname;
// Illustrative 2025-scale population and productive capability, not calibrated statistics.
const profiles = [
 ['USA','United States',335,-99,38,8.5,1.5,1.3,1.1,1,2],
 ['CAN','Canada',40,-105,57,8,1.7,2.2,2.0,1,2],
 ['MEX','Mexico',130,-102,24,5.5,1.1,1.2,1.2,1,1],
 ['BRA','Brazil',216,-52,-12,5.1,2.1,1.5,2.0,3,1],
 ['ARG','Argentina',46,-64,-35,5.3,2.0,1.2,1.1,3,0],
 ['CHL','Chile',20,-71,-30,6.0,1.0,0.7,3.0,3,2],
 ['COL','Colombia',52,-74,4,4.8,1.6,1.4,1.0,3,0],
 ['PER','Peru',34,-75,-10,4.5,1.2,1.0,2.2,3,1],
 ['GBR','United Kingdom',68,-2,54,8.2,0.8,0.9,0.5,0,3],
 ['FRA','France',68,2,47,8.1,1.7,1.0,0.6,2,0],
 ['DEU','Germany',84,10,51,8.8,0.8,0.5,0.7,2,1],
 ['ESP','Spain',48,-4,40,7.0,1.5,0.6,0.8,2,0],
 ['ITA','Italy',59,12,43,7.3,1.1,0.5,0.5,2,1],
 ['NLD','Netherlands',18,5,52,8.6,1.4,0.7,0.4,2,2],
 ['SWE','Sweden',11,16,63,8.8,0.7,1.4,1.6,2,3],
 ['POL','Poland',38,19,52,6.6,1.4,1.2,1.1,2,1],
 ['TUR','Turkey',86,35,39,5.7,1.5,0.6,1.1,0,1],
 ['RUS','Russia',144,95,61,6.4,1.4,2.8,2.2,0,1],
 ['CHN','China',1410,104,35,7.1,0.85,0.65,0.8,4,1],
 ['IND','India',1430,79,23,4.8,1.3,0.7,0.65,0,1],
 ['JPN','Japan',123,138,37,9.0,0.55,0.3,0.3,4,3],
 ['KOR','South Korea',52,128,36,8.8,0.5,0.3,0.4,4,3],
 ['IDN','Indonesia',280,117,-3,4.9,1.7,1.7,1.6,4,0],
 ['VNM','Vietnam',100,107,16,5.3,1.7,0.8,0.9,4,1],
 ['THA','Thailand',72,101,15,5.9,1.8,0.7,0.8,4,2],
 ['MYS','Malaysia',34,102,4,6.4,1.5,1.6,1.0,4,2],
 ['AUS','Australia',27,134,-25,8.0,2.0,2.7,3.0,4,2],
 ['NZL','New Zealand',5.2,173,-41,7.7,2.6,1.0,0.6,4,0],
 ['SAU','Saudi Arabia',37,45,24,6.2,0.25,4.0,0.7,0,1],
 ['IRN','Iran',89,54,32,5.2,0.9,2.5,1.3,0,1],
 ['ZAF','South Africa',61,25,-29,5.1,1.1,1.5,2.5,5,1],
 ['NGA','Nigeria',224,8,9,3.2,1.4,2.2,1.1,5,0],
 ['EGY','Egypt',112,30,27,4.2,0.8,1.2,0.8,5,1],
 ['KEN','Kenya',55,38,0,3.8,1.6,0.6,0.8,5,2],
 ['ETH','Ethiopia',127,40,9,2.8,1.5,0.4,0.8,5,0],
 ['COD','DR Congo',102,23,-3,2.4,1.0,0.6,3.5,5,1],
];
let spec = 'with Economy;\npackage Starting_World is\n   procedure Populate (Nations : out Economy.Country_Array);\nend Starting_World;\n';
let body = 'with Ada.Strings.Fixed;\npackage body Starting_World is\n   pragma Style_Checks (Off);\n   procedure Populate (Nations : out Economy.Country_Array) is\n      use Economy;\n   begin\n      Nations := [others => <>];\n';
profiles.forEach((p,i)=>{
 const [iso,name,pop,lon,lat,tech,food,energy,mineral,bloc,pri]=p;
 const num=v=>Number(v).toFixed(3);
 body+=`      Nations (${i+1}).Name := Ada.Strings.Fixed.Head ("${name}", 24);\n`;
 body+=`      Nations (${i+1}).ISO := "${iso}";\n`;
 for(const [key,v] of Object.entries({Population:pop,Longitude:lon,Latitude:lat,Infrastructure:Math.max(1,tech-.3),Prosperity:tech*8.5,Tariff:pri===2?.03:pri===1?.14:.08,Industry_Budget:pri===1?.50:.32,Research_Budget:pri===3?.45:.23,Infrastructure_Budget:.22}))
  body+=`      Nations (${i+1}).${key} := ${num(v)};\n`;
 body+=`      Nations (${i+1}).Bloc := ${bloc};\n      Nations (${i+1}).Priority := Philosophy'Val (${pri});\n`;
 body+=`      Nations (${i+1}).Tech := [Agriculture => ${num(Math.min(10,tech*1.03))}, Extraction => ${num(tech)}, Manufacturing => ${num(tech)}, Advanced => ${num(Math.max(1,tech-.4))}, Logistics => ${num(tech)}];\n`;
 body+=`      Nations (${i+1}).Resources := [Food => ${num(food)}, Energy => ${num(energy)}, Minerals => ${num(mineral)}, others => 1.0];\n`;
 if(iso==='ETH')body+=`      Nations (${i+1}).Landlocked := True;\n`;
});
body+='   end Populate;\nend Starting_World;\n';
fs.writeFileSync(path.join(root,'src/starting_world.ads'),spec);
fs.writeFileSync(path.join(root,'src/starting_world.adb'),body);
const geo=JSON.parse(fs.readFileSync(path.join(root,'share/countries.geojson'),'utf8'));
const cross=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
function inside(p,a,b,c){return cross(a,b,p)>=-1e-8&&cross(b,c,p)>=-1e-8&&cross(c,a,p)>=-1e-8;}
function triangulate(ring){
 let pts=ring.slice(0,-1).filter((p,i,a)=>!i||Math.abs(p[0]-a[i-1][0])+Math.abs(p[1]-a[i-1][1])>1e-8);
 const area=pts.reduce((s,p,i)=>s+p[0]*pts[(i+1)%pts.length][1]-pts[(i+1)%pts.length][0]*p[1],0);
 if(area<0)pts.reverse();
 let ids=pts.map((_,i)=>i), result=[],guard=0;
 while(ids.length>3&&guard++<pts.length*3){
  let found=false;
  for(let j=0;j<ids.length;j++){
   const a=pts[ids[(j+ids.length-1)%ids.length]],b=pts[ids[j]],c=pts[ids[(j+1)%ids.length]];
   if(cross(a,b,c)<=1e-9)continue;
   if(ids.some((id,k)=>k!==j&&k!==(j+1)%ids.length&&k!==(j+ids.length-1)%ids.length&&inside(pts[id],a,b,c)))continue;
   result.push([a,b,c]); ids.splice(j,1); found=true; break;
  }
  if(!found)break;
 }
 if(ids.length===3)result.push(ids.map(i=>pts[i]));
 return result;
}
let triangles=[],segments=[];
for(const f of geo.features){
 if(f.properties.ADM0_A3==='ATA')continue;
 let id=profiles.findIndex(p=>p[0]===f.properties.ADM0_A3)+1;
 let polygons=f.geometry.type==='Polygon'?[f.geometry.coordinates]:f.geometry.coordinates;
 for(const poly of polygons){
  let ring=poly[0];
  for(const tri of triangulate(ring))triangles.push([id,...tri.flat()]);
  for(let j=1;j<ring.length;j++)if(Math.abs(ring[j][0]-ring[j-1][0])<180)segments.push([id,...ring[j-1],...ring[j]]);
 }
}
const fmt=r=>r.map((n,i)=>i?Number(n).toFixed(5):n).join(' ');
fs.writeFileSync(path.join(root,'share/world.map'),triangles.length+'\n'+triangles.map(fmt).join('\n')+'\n'+segments.length+'\n'+segments.map(fmt).join('\n')+'\n');
console.log(`${profiles.length} economies, ${triangles.length} triangles, ${segments.length} border segments.`);
