import assert from 'node:assert/strict'
import test from 'node:test'
import {
  computeLeaderboardListRanks,
  computeLeaderboardUserRank,
  normalizeLeaderboardSortType,
  type LeaderboardSortType,
  type LeaderboardStatRow,
} from './leaderboard.rank-utils'

const sampleRows: LeaderboardStatRow[] = [
  {
    id: 'u_alpha',
    xp: 1200,
    wins: 18,
    longest_streak: 7,
    elo_rating: 1510,
    games_played: 12,
  },
  {
    id: 'u_bravo',
    xp: 1700,
    wins: 18,
    longest_streak: 9,
    elo_rating: 1600,
    games_played: 24,
  },
  {
    id: 'u_charlie',
    xp: 1700,
    wins: 13,
    longest_streak: 4,
    elo_rating: 1400,
    games_played: 17,
  },
  {
    id: 'u_delta',
    xp: 9000,
    wins: 99,
    longest_streak: 30,
    elo_rating: 2500,
    games_played: 1,
  },
  {
    id: 'u_echo',
    xp: 500,
    wins: 4,
    longest_streak: 2,
    elo_rating: 1100,
    games_played: 6,
  },
  {id:'u_new',xp:10000,wins:0,longest_streak:0,elo_rating:0,games_played:0}
]

const sorts: LeaderboardSortType[] = ['xp', 'wins', 'elo', 'streak']

test('rank parity: list ordering rank matches rank endpoint logic for all leaderboard tabs', () => {
  for (const sort of sorts) {
    const listRanks = computeLeaderboardListRanks(sampleRows, sort)

    for (const row of sampleRows) {
      const endpointRank = computeLeaderboardUserRank(sampleRows, row.id, sort)

      if (row.games_played < 1) {
        // Ineligible users (0 games) should have rank 0 in both endpoints
        assert.equal(
          endpointRank,
          0,
          `expected ineligible user ${row.id} (${row.games_played} games) to have rank 0 for ${sort}`,
        )
        // Ineligible users should NOT appear in the eligible-only list ranks
        assert.equal(
          listRanks.has(row.id),
          false,
          `expected ineligible user ${row.id} (${row.games_played} games) to be absent from eligible list for ${sort}`,
        )
      } else {
        // Eligible users should have matching ranks
        assert.equal(
          endpointRank,
          listRanks.get(row.id),
          `parity mismatch for eligible user ${row.id} on ${sort}`,
        )
      }
    }
  }
})

test('normalizeLeaderboardSortType falls back to xp for unsupported values', () => {
  assert.equal(normalizeLeaderboardSortType(undefined), 'xp')
  assert.equal(normalizeLeaderboardSortType(null), 'xp')
  assert.equal(normalizeLeaderboardSortType('bad-sort'), 'xp')
  assert.equal(normalizeLeaderboardSortType('wins'), 'wins')
  assert.equal(normalizeLeaderboardSortType('elo'), 'elo')
})

test('real SQL leaderboard agrees with rank utility, excluding unplayed users and breaking ties by XP', async()=>{
 const {readFileSync}=await import('node:fs')
 const {testDB}=await import('../test_support/sqlite')
 const {leaderboardRoutes}=await import('./leaderboard')
 const db=testDB(readFileSync(new URL('../../schema/d1-schema.sql',import.meta.url),'utf8'))
 for(const r of sampleRows){
  await db.prepare('INSERT INTO users(id,username,device_id,xp) VALUES(?,?,?,?)').bind(r.id,r.id,r.id,r.xp).run()
  await db.prepare('INSERT INTO user_stats(user_id,wins,longest_streak,elo_rating,games_played) VALUES(?,?,?,?,?)').bind(r.id,r.wins,r.longest_streak,r.elo_rating,r.games_played).run()
 }
 for(const sort of sorts){
  const response=await leaderboardRoutes.request(`/?type=${sort}`,undefined,{DB:db} as any)
  assert.equal(response.status,200)
  const {leaderboard}=await response.json() as any
  const ranks=computeLeaderboardListRanks(sampleRows,sort)
  for(const row of leaderboard)assert.equal(row.rank,ranks.get(row.id)??0,`${sort}:${row.id}`)
 }
})
