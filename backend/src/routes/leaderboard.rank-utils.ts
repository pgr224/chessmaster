export type LeaderboardSortType = 'xp' | 'wins' | 'streak' | 'elo'

export type LeaderboardStatRow = {
  id: string
  xp: number
  wins: number
  longest_streak: number
  elo_rating: number
  games_played: number
}

export function normalizeLeaderboardSortType(type: string | null | undefined): LeaderboardSortType {
  if (type === 'wins' || type === 'streak' || type === 'elo') {
    return type
  }
  return 'xp'
}

export function getLeaderboardSortValue(
  row: LeaderboardStatRow,
  type: LeaderboardSortType,
): number {
  if (type === 'wins') return row.wins
  if (type === 'streak') return row.longest_streak
  if (type === 'elo') return row.elo_rating
  return row.xp
}

export function isLeaderboardEligible(row: Pick<LeaderboardStatRow, 'games_played'>): boolean {
  return row.games_played >= 1
}

export function computeLeaderboardListRanks(
  rows: LeaderboardStatRow[],
  type: LeaderboardSortType,
): Map<string, number> {
  const eligible = rows
    .filter(isLeaderboardEligible)
    .slice()
    .sort((a, b) => {
      const diff = getLeaderboardSortValue(b, type) - getLeaderboardSortValue(a, type)
      if (diff !== 0) return diff
      return a.id.localeCompare(b.id)
    })

  const ranks = new Map<string, number>()
  let previousValue: number | null = null
  let previousRank = 0

  for (let i = 0; i < eligible.length; i++) {
    const row = eligible[i]
    const value = getLeaderboardSortValue(row, type)
    const rank = previousValue !== null && value === previousValue ? previousRank : i + 1
    ranks.set(row.id, rank)
    previousValue = value
    previousRank = rank
  }

  return ranks
}

export function computeLeaderboardUserRank(
  rows: LeaderboardStatRow[],
  userId: string,
  type: LeaderboardSortType,
): number {
  const me = rows.find((row) => row.id === userId)
  if (!me || !isLeaderboardEligible(me)) {
    return 0
  }

  const myValue = getLeaderboardSortValue(me, type)
  const betterCount = rows.filter(
    (row) => isLeaderboardEligible(row) && getLeaderboardSortValue(row, type) > myValue,
  ).length

  return betterCount + 1
}
