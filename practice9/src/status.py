"""Формирование строки состояния для учебного репозитория."""


def format_status(version: str, deployed: bool) -> str:
    """Возвращает человекочитаемое состояние публикации."""
    state = "deployed" if deployed else "draft"
    return f"{version}: {state}"


if __name__ == "__main__":
    print(format_status("1.0", deployed=True))
