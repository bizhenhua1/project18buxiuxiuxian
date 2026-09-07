import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {CARD_LIBRARY,createUnit} from '../js/unit.js';
import {BALANCE,defReduction} from '../js/balance.js';
import * as combat from '../js/combat.js';
import * as fog from '../js/world-fog.js';
const out='godot/data';fs.mkdirSync(out,{recursive:true});
const source=fs.readFileSync('world-demo.html','utf8');
const generator=source.slice(source.indexOf('    const TILE_W'),source.indexOf('    const canvas ='));
const maps=[];
for(let seed=1842;seed<1874;seed++){
 let v=seed>>>0; const math=Object.create(Math); math.random=()=>{v=(Math.imul(1664525,v)+1013904223)>>>0;return v/4294967296;};
 const value=vm.runInNewContext(generator+'\nJSON.stringify(plan(20,20));',{Math:math});
 maps.push({seed,cols:20,rows:20,...JSON.parse(value)});
}
fs.writeFileSync(out+'/world_samples.json',JSON.stringify({schema:1,source:'world-demo.html',sha256:crypto.createHash('sha256').update(source).digest('hex'),maps},null,2));
const worldReference=[];
for(let mapIndex=0;mapIndex<maps.length;mapIndex++){
 const map=maps[mapIndex],lookup=new Map(map.grid.map(c=>[fog.cellKey(c.c,c.r),c]));
 for(const player of map.grid.filter((c,i)=>i%5===0)){
  const state=fog.createFog();map.grid.filter((c,i)=>i%3===0).forEach(c=>fog.remember(state,c));
  fog.remember(state,player);
  const sight=fog.computeSight(lookup,player,map.cols,map.rows);
  worldReference.push({mapIndex,player:[player.c,player.r],explored:[...state.explored],radius:fog.visionRadius(player),sight:[...sight].sort(),levels:map.grid.map(c=>({key:[c.c,c.r],level:fog.levelOf(c.c,c.r,state,sight)}))});
 }
}
fs.writeFileSync(out+'/world_reference.json',JSON.stringify(worldReference));
fs.writeFileSync(out+'/battle_cards.json',JSON.stringify({schema:1,balance:BALANCE,cards:CARD_LIBRARY},null,2));
const fixtures=[];
for(const card of CARD_LIBRARY) for(const side of ['player','enemy']) for(const stage of [0,1,7,16]){
 const unit=createUnit(card.id,side,0,stage);
 fixtures.push({id:card.id,side,stage,expected:{hp:unit.hp,atk:unit.atk,cd:unit.cd,physDef:unit.physDef,spellDef:unit.spellDef,critChance:unit.critChance}});
}
const damage=[];
for(const stage of [0,7,16])for(const type of ['phys','spell',null])for(const shield of [0,12]){
 const target=createUnit('shitoujing','enemy',0,stage);target.shield=shield;target.dmgReduce=.15;
 const input=JSON.parse(JSON.stringify(target));const events=combat.applyDamage(target,23,type);
 damage.push({input,amount:23,type,expected:{hp:target.hp,shield:target.shield,status:target.status,dealt:events[0]?.dealt||0}});
}
const actions=[];
for(const card of CARD_LIBRARY)for(const mode of ['station','held']){
 const allies=[createUnit('daotong','player',0,7),createUnit(card.id,'player',1,7),createUnit('qingfeng-jian','player',2,7),createUnit('waci-yin','player',3,7)];
 const foes=['huoli','jinchan','shitoujing'].map((id,i)=>createUnit(id,'enemy',i,7));
 const attacker=allies[1];if(attacker.cardType==='fabao')attacker.mode=mode;
 attacker.critChance=1;attacker.swordEcho=.25;allies[0].hp=5;allies[2].hp=8;
 const input=JSON.parse(JSON.stringify({allies,foes}));
 const events=combat.act(attacker,{playerQueue:allies,enemyQueue:foes},1000);
 actions.push({id:card.id,mode,input,shots:events.filter(e=>e.type==='shot').map(e=>({from:e.from.uid,to:e.to.uid,amount:e.amount,style:e.style,crit:e.crit,secondary:e.secondary})),units:[...allies,...foes].map(u=>({uid:u.uid,hp:u.hp,shield:u.shield,cdLeft:u.cdLeft,healDone:u.healDone||0}))});
}
fs.writeFileSync(out+'/battle_reference.json',JSON.stringify({stats:fixtures,damage,actions},null,2));
console.log(`Exported ${maps.length} original-generator islands, ${CARD_LIBRARY.length} cards, ${fixtures.length+damage.length} reference cases`);
