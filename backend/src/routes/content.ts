import { Hono } from 'hono'
import type { Env } from '../index'

const contentRoutes = new Hono<{ Bindings: Env }>()

// Get daily content (e.g. puzzle of the day, daily article)
contentRoutes.get('/daily', async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT * FROM daily_content 
     WHERE publish_date <= date('now') 
     ORDER BY publish_date DESC LIMIT 5`
  ).all()

  return c.json({ content: results })
})

// Get content by category
contentRoutes.get('/category/:category', async (c) => {
  const category = c.req.param('category')
  const { results } = await c.env.DB.prepare(
    `SELECT * FROM daily_content 
     WHERE category = ? AND publish_date <= date('now') 
     ORDER BY publish_date DESC LIMIT 20`
  ).bind(category).all()

  return c.json({ content: results })
})

export { contentRoutes }
