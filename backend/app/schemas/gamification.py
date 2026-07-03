from pydantic import BaseModel


class AchievementEntry(BaseModel):
    code: str
    title: str
    unlocked: bool


class GamificationProfileResponse(BaseModel):
    level: int
    level_band: str
    total_xp: float
    xp_to_next_level: float
    progress_pct: float
    sessions_completed: int
    records_count: int
    longest_streak_days: int
    lifetime_tonnage_kg: float
    achievements: list[AchievementEntry]
