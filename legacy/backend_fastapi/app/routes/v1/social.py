from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.social import Challenge, ChallengeParticipant
from app.models.user import User
from app.schemas.social import (
    ChallengeCreate,
    ChallengeDetail,
    ChallengeJoin,
    ChallengeSummary,
)
from app.services.social import (
    build_leaderboard,
    generate_invite_code,
    get_membership,
)

router = APIRouter(prefix="/api/v1/challenges", tags=["challenges"])


def _summary(challenge: Challenge, user: User) -> dict:
    return {
        "id": challenge.id,
        "name": challenge.name,
        "metric": challenge.metric,
        "starts_on": challenge.starts_on,
        "ends_on": challenge.ends_on,
        "invite_code": challenge.invite_code,
        "participant_count": len(challenge.participants),
        "is_owner": challenge.owner_id == user.id,
    }


@router.post("", response_model=ChallengeDetail, status_code=status.HTTP_201_CREATED)
def create_challenge(
    payload: ChallengeCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    challenge = Challenge(
        owner_id=current_user.id,
        name=payload.name,
        description=payload.description,
        metric=payload.metric,
        starts_on=payload.starts_on,
        ends_on=payload.ends_on,
        invite_code=generate_invite_code(db),
    )
    challenge.participants.append(ChallengeParticipant(user_id=current_user.id))
    db.add(challenge)
    db.commit()
    db.refresh(challenge)
    return {
        **_summary(challenge, current_user),
        "description": challenge.description,
        "leaderboard": build_leaderboard(db, challenge, current_user.id),
    }


@router.get("", response_model=list[ChallengeSummary])
def list_my_challenges(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    challenges = (
        db.query(Challenge)
        .join(ChallengeParticipant, ChallengeParticipant.challenge_id == Challenge.id)
        .filter(ChallengeParticipant.user_id == current_user.id)
        .order_by(Challenge.created_at.desc())
        .all()
    )
    return [_summary(c, current_user) for c in challenges]


@router.post("/join", response_model=ChallengeDetail)
def join_challenge(
    payload: ChallengeJoin,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    challenge = (
        db.query(Challenge)
        .filter(Challenge.invite_code == payload.invite_code.strip().upper())
        .first()
    )
    if challenge is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No existe un reto con ese codigo de invitacion",
        )
    if get_membership(db, challenge.id, current_user.id) is None:
        db.add(ChallengeParticipant(challenge_id=challenge.id, user_id=current_user.id))
        db.commit()
        db.refresh(challenge)
    return {
        **_summary(challenge, current_user),
        "description": challenge.description,
        "leaderboard": build_leaderboard(db, challenge, current_user.id),
    }


@router.get("/{challenge_id}", response_model=ChallengeDetail)
def get_challenge(
    challenge_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    challenge = db.get(Challenge, challenge_id)
    if challenge is None or get_membership(db, challenge_id, current_user.id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Reto no encontrado"
        )
    return {
        **_summary(challenge, current_user),
        "description": challenge.description,
        "leaderboard": build_leaderboard(db, challenge, current_user.id),
    }


@router.delete("/{challenge_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
def leave_challenge(
    challenge_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    challenge = db.get(Challenge, challenge_id)
    if challenge is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Reto no encontrado"
        )
    # El dueño no "sale": borra el reto completo.
    if challenge.owner_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sos el dueño del reto: usa DELETE para eliminarlo",
        )
    membership = get_membership(db, challenge_id, current_user.id)
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="No participas en este reto"
        )
    db.delete(membership)
    db.commit()


@router.delete("/{challenge_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_challenge(
    challenge_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    challenge = db.get(Challenge, challenge_id)
    if challenge is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Reto no encontrado"
        )
    if challenge.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el dueño puede eliminar el reto",
        )
    db.delete(challenge)
    db.commit()
