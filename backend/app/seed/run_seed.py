from app.core.database import SessionLocal
from app.models.exercise import Exercise
from app.seed.exercises_data import EXERCISES


def seed_exercises() -> None:
    db = SessionLocal()
    try:
        existing_slugs = {row[0] for row in db.query(Exercise.slug).all()}
        created = 0
        for data in EXERCISES:
            if data["slug"] in existing_slugs:
                continue
            db.add(Exercise(**data))
            created += 1
        db.commit()
        print(
            f"Seed completo: {created} ejercicios nuevos, {len(EXERCISES) - created} ya existían."
        )
    finally:
        db.close()


if __name__ == "__main__":
    seed_exercises()
