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
]

const sorts: LeaderboardSortType[] = ['xp', 'wins', 'elo', 'streak']

test('rank parity: list ordering rank matches rank endpoint logic for all leaderboard tabs', () => {
  for (const sort of sorts) {
    const listRanks = computeLeaderboardListRanks(sampleRows, sort)

    for (const row of sampleRows) {
      const endpointRank = computeLeaderboardUserRank(sampleRows, row.id, sort)

      if (row.games_played <= 1) {
        // Ineligible users (<=1 games) should have rank 0 in both endpoints
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
