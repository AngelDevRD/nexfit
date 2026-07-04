from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.social import ChallengeMetric


class ChallengeCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    metric: ChallengeMetric
    starts_on: date
    ends_on: date

    @model_validator(mode="after")
    def _check_dates(self) -> "ChallengeCreate":
        if self.ends_on < self.starts_on:
            raise ValueError("ends_on no puede ser anterior a starts_on")
        return self


class ChallengeJoin(BaseModel):
    invite_code: str = Field(min_length=1, max_length=8)


class LeaderboardEntry(BaseModel):
    user_id: int
    name: str
    value: float
    rank: int
    is_me: bool


class ChallengeSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    metric: ChallengeMetric
    starts_on: date
    ends_on: date
    invite_code: str
    participant_count: int
    is_owner: bool


class ChallengeDetail(ChallengeSummary):
    description: str | None
    leaderboard: list[LeaderboardEntry]
