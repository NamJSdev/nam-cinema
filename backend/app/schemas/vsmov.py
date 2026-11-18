from typing import Any, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class VsmovTmdbRef(BaseModel):
    model_config = ConfigDict(extra="ignore")

    type: Optional[str] = None
    id: Optional[str] = None
    season: Optional[int] = None
    vote_average: float = 0.0
    vote_count: int = 0

    @field_validator("id", mode="before")
    @classmethod
    def coerce_id(cls, value: Any) -> Optional[str]:
        if value is None or value == "":
            return None
        return str(value).strip()

    @field_validator("vote_average", mode="before")
    @classmethod
    def coerce_vote_average(cls, value: Any) -> float:
        if value is None or value == "":
            return 0.0
        try:
            return round(float(value), 1)
        except (TypeError, ValueError):
            return 0.0

    @field_validator("vote_count", mode="before")
    @classmethod
    def coerce_vote_count(cls, value: Any) -> int:
        if value is None or value == "":
            return 0
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return 0

    @property
    def numeric_tmdb_id(self) -> Optional[int]:
        if self.id and self.id.isdigit() and int(self.id) > 0:
            return int(self.id)
        return None


class VsmovImdbRef(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: Optional[str] = None


class VsmovTimeRef(BaseModel):
    model_config = ConfigDict(extra="ignore")

    time: Optional[str] = None


class VsmovTaxonomyRef(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    id: int = Field(default=0, alias="_id")
    name: str = ""
    slug: str = ""

    @field_validator("id", mode="before")
    @classmethod
    def coerce_taxonomy_id(cls, value: Any) -> int:
        if value is None:
            return 0
        try:
            return int(value)
        except (TypeError, ValueError):
            return 0


class VsmovDetailCategoryRef(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: int = 0
    name: str = ""
    slug: str = ""


class VsmovPagination(BaseModel):
    model_config = ConfigDict(extra="ignore")

    totalItems: int = 0
    totalItemsPerPage: int = 24
    currentPage: int = 1
    totalPages: int = 1

    @field_validator("totalItems", "totalItemsPerPage", "currentPage", "totalPages", mode="before")
    @classmethod
    def coerce_int_fields(cls, value: Any) -> int:
        if value is None or value == "":
            return 1
        try:
            return int(value)
        except (TypeError, ValueError):
            return 1


class VsmovMovieListItem(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    internal_id: int = Field(default=0, alias="_id")
    name: str
    origin_name: str = ""
    slug: str
    poster_url: Optional[str] = None
    thumb_url: Optional[str] = None
    year: Optional[int] = None
    tmdb: VsmovTmdbRef = Field(default_factory=VsmovTmdbRef)
    imdb: VsmovImdbRef = Field(default_factory=VsmovImdbRef)
    modified: VsmovTimeRef = Field(default_factory=VsmovTimeRef)

    @field_validator("poster_url", "thumb_url", mode="before")
    @classmethod
    def coerce_optional_str(cls, value: Any) -> Optional[str]:
        if isinstance(value, str):
            cleaned = value.strip()
            return cleaned if cleaned else None
        return None

    @field_validator("year", mode="before")
    @classmethod
    def coerce_year(cls, value: Any) -> Optional[int]:
        if value is None or value == "" or not isinstance(value, (int, float, str)):
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    @property
    def resolved_tmdb_id(self) -> int:
        return self.tmdb.numeric_tmdb_id or self.internal_id

    @property
    def resolved_content_type(self) -> str:
        if self.tmdb.type in ("tv", "series"):
            return "tv"
        return "movie"


class VsmovListResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    status: Any = True
    items: list[VsmovMovieListItem] = Field(default_factory=list)
    pathImage: Optional[str] = None
    pagination: VsmovPagination = Field(default_factory=VsmovPagination)


class VsmovTaxonomyDataEnvelope(BaseModel):
    model_config = ConfigDict(extra="ignore")

    items: list[VsmovTaxonomyRef] = Field(default_factory=list)


class VsmovTaxonomyListResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    status: str = "success"
    message: str = ""
    data: VsmovTaxonomyDataEnvelope = Field(default_factory=VsmovTaxonomyDataEnvelope)


class VsmovEpisodeDataItem(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: str = ""
    slug: str = ""
    filename: Optional[str] = None
    link_embed: Optional[str] = None
    link_m3u8: Optional[str] = None


class VsmovServerGroup(BaseModel):
    model_config = ConfigDict(extra="ignore")

    server_name: str = ""
    server_data: list[VsmovEpisodeDataItem] = Field(default_factory=list)

    @field_validator("server_name", mode="before")
    @classmethod
    def clean_server_name(cls, value: Any) -> str:
        if not value:
            return "Server #1"
        return " ".join(str(value).split())


class VsmovMovieDetailData(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    internal_id: int = Field(default=0, alias="_id")
    name: str = ""
    origin_name: str = ""
    slug: str = ""
    content: str = ""
    type: str = "single"  # "single" | "series" | "hoathinh" | "tvshows"
    status: Optional[str] = None
    poster_url: Optional[str] = None
    thumb_url: Optional[str] = None
    trailer_url: Optional[str] = None
    time: Optional[str] = None
    episode_current: Optional[str] = None
    episode_total: Optional[str] = None
    quality: Optional[str] = None
    lang: Optional[str] = None
    year: Optional[int] = None
    actor: list[str] = Field(default_factory=list)
    director: list[str] = Field(default_factory=list)
    category: list[VsmovDetailCategoryRef] = Field(default_factory=list)
    country: list[VsmovDetailCategoryRef] = Field(default_factory=list)
    tmdb: VsmovTmdbRef = Field(default_factory=VsmovTmdbRef)
    imdb: VsmovImdbRef = Field(default_factory=VsmovImdbRef)

    @field_validator(
        "poster_url",
        "thumb_url",
        "trailer_url",
        "time",
        "episode_current",
        "episode_total",
        "quality",
        "lang",
        "status",
        mode="before",
    )
    @classmethod
    def coerce_detail_optional_str(cls, value: Any) -> Optional[str]:
        if isinstance(value, str):
            cleaned = value.strip()
            return cleaned if cleaned else None
        if isinstance(value, (int, float)):
            return str(value)
        return None

    @field_validator("content", "name", "origin_name", "slug", mode="before")
    @classmethod
    def coerce_detail_str(cls, value: Any) -> str:
        if isinstance(value, str):
            return value.strip()
        return ""

    @field_validator("actor", "director", mode="before")
    @classmethod
    def coerce_str_list(cls, value: Any) -> list[str]:
        if isinstance(value, list):
            return [str(x).strip() for x in value if isinstance(x, (str, int)) and str(x).strip()]
        return []

    @field_validator("poster_url", "thumb_url", mode="before")
    @classmethod
    def coerce_optional_str(cls, value: Any) -> Optional[str]:
        if isinstance(value, str):
            cleaned = value.strip()
            return cleaned if cleaned else None
        return None

    @field_validator("year", mode="before")
    @classmethod
    def coerce_year(cls, value: Any) -> Optional[int]:
        if value is None or value == "" or not isinstance(value, (int, float, str)):
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    @property
    def resolved_tmdb_id(self) -> int:
        return self.tmdb.numeric_tmdb_id or self.internal_id

    @property
    def is_series(self) -> bool:
        return self.type == "series" or self.tmdb.type == "tv"


class VsmovDetailResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    status: Any = True
    msg: Optional[str] = None
    movie: Optional[VsmovMovieDetailData] = None
    episodes: list[VsmovServerGroup] = Field(default_factory=list)
