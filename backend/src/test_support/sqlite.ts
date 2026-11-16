import { DatabaseSync } from 'node:sqlite'
export function testDB(schema:string):D1Database {
 const db=new DatabaseSync(':memory:');db.exec(schema)
 const prepare=(sql:string,params:unknown[]=[]):any=>({
  bind:(...values:unknown[])=>prepare(sql,values),
  first:async(column?:string)=>{const row=db.prepare(sql).get(...params as any[]) as any;return row?(column?row[column]:row):null},
  all:async()=>({results:db.prepare(sql).all(...params as any[]),success:true,meta:{}}),
  run:async()=>{const result=db.prepare(sql).run(...params as any[]);return {success:true,results:[],meta:{changes:Number(result.changes)}}},
 })
 return {prepare,batch:async(statements:any[])=>{db.exec('BEGIN');try{const results=[];for(const statement of statements)results.push(await statement.run());db.exec('COMMIT');return results}catch(error){db.exec('ROLLBACK');throw error}}} as unknown as D1Database
}
