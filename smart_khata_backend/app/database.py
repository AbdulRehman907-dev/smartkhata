import asyncio
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
import copy

try:
    from motor.motor_asyncio import AsyncIOMotorClient
    HAS_MOTOR = True
except ImportError:
    HAS_MOTOR = False

from app.config import settings

class InMemoryCursor:
    def __init__(self, docs: List[Dict[str, Any]]):
        self._docs = docs
        self._sort_key = None
        self._sort_direction = 1
        self._skip_count = 0
        self._limit_count = None

    def sort(self, key_or_list, direction=1):
        if isinstance(key_or_list, list):
            if key_or_list:
                self._sort_key, self._sort_direction = key_or_list[0][0], key_or_list[0][1]
        else:
            self._sort_key = key_or_list
            self._sort_direction = direction
        return self

    def skip(self, count: int):
        self._skip_count = count
        return self

    def limit(self, count: int):
        self._limit_count = count
        return self

    async def to_list(self, length: Optional[int] = None) -> List[Dict[str, Any]]:
        docs = list(self._docs)
        if self._sort_key:
            reverse = self._sort_direction == -1
            docs.sort(key=lambda x: x.get(self._sort_key, ""), reverse=reverse)
        if self._skip_count:
            docs = docs[self._skip_count:]
        if self._limit_count is not None:
            docs = docs[:self._limit_count]
        if length is not None:
            docs = docs[:length]
        return [copy.deepcopy(d) for d in docs]

class InMemoryCollection:
    def __init__(self, name: str):
        self.name = name
        self.docs: List[Dict[str, Any]] = []

    def _matches(self, doc: Dict[str, Any], query: Dict[str, Any]) -> bool:
        for k, v in query.items():
            if k == "$or" and isinstance(v, list):
                if not any(self._matches(doc, q) for q in v):
                    return False
                continue
            if k == "$and" and isinstance(v, list):
                if not all(self._matches(doc, q) for q in v):
                    return False
                continue
            
            doc_val = doc.get(k)
            if isinstance(v, dict):
                for op, target in v.items():
                    if op == "$gte" and not (doc_val is not None and doc_val >= target):
                        return False
                    elif op == "$gt" and not (doc_val is not None and doc_val > target):
                        return False
                    elif op == "$lte" and not (doc_val is not None and doc_val <= target):
                        return False
                    elif op == "$lt" and not (doc_val is not None and doc_val < target):
                        return False
                    elif op == "$ne" and doc_val == target:
                        return False
                    elif op == "$regex" and isinstance(target, str):
                        import re
                        options = v.get("$options", "")
                        flags = re.IGNORECASE if "i" in options else 0
                        if not doc_val or not re.search(target, str(doc_val), flags):
                            return False
                    elif op == "$in" and doc_val not in target:
                        return False
            else:
                if doc_val != v:
                    return False
        return True

    async def insert_one(self, doc: Dict[str, Any]):
        d = copy.deepcopy(doc)
        if "_id" not in d:
            import uuid
            d["_id"] = str(uuid.uuid4())
        self.docs.append(d)
        class InsertOneResult:
            inserted_id = d["_id"]
        return InsertOneResult()

    async def insert_many(self, docs: List[Dict[str, Any]]):
        inserted_ids = []
        for doc in docs:
            res = await self.insert_one(doc)
            inserted_ids.append(res.inserted_id)
        class InsertManyResult:
            def __init__(self, ids):
                self.inserted_ids = ids
        return InsertManyResult(inserted_ids)

    async def find_one(self, query: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        for d in self.docs:
            if self._matches(d, query):
                return copy.deepcopy(d)
        return None

    def find(self, query: Optional[Dict[str, Any]] = None) -> InMemoryCursor:
        query = query or {}
        matched = [d for d in self.docs if self._matches(d, query)]
        return InMemoryCursor(matched)

    async def update_one(self, query: Dict[str, Any], update: Dict[str, Any], upsert: bool = False):
        matched = None
        for d in self.docs:
            if self._matches(d, query):
                matched = d
                break
        
        class UpdateResult:
            matched_count = 1 if matched else 0
            modified_count = 0
            upserted_id = None

        res = UpdateResult()
        if not matched and upsert:
            import uuid
            matched = copy.deepcopy(query)
            # Remove operators from query if present
            matched = {k: v for k, v in matched.items() if not k.startswith("$")}
            matched["_id"] = str(uuid.uuid4())
            self.docs.append(matched)
            res.upserted_id = matched["_id"]

        if matched:
            res.modified_count = 1
            if "$set" in update:
                for k, v in update["$set"].items():
                    matched[k] = copy.deepcopy(v)
            if "$inc" in update:
                for k, v in update["$inc"].items():
                    matched[k] = matched.get(k, 0) + v
            if "$push" in update:
                for k, v in update["$push"].items():
                    if k not in matched or not isinstance(matched[k], list):
                        matched[k] = []
                    matched[k].append(copy.deepcopy(v))
        return res

    async def delete_one(self, query: Dict[str, Any]):
        for i, d in enumerate(self.docs):
            if self._matches(d, query):
                self.docs.pop(i)
                class DeleteResult:
                    deleted_count = 1
                return DeleteResult()
        class DeleteResult:
            deleted_count = 0
        return DeleteResult()

    async def count_documents(self, query: Dict[str, Any]) -> int:
        return len([d for d in self.docs if self._matches(d, query)])


class InMemoryDatabase:
    def __init__(self):
        self.collections: Dict[str, InMemoryCollection] = {}

    def get_collection(self, name: str) -> InMemoryCollection:
        if name not in self.collections:
            self.collections[name] = InMemoryCollection(name)
        return self.collections[name]

    def __getitem__(self, name: str) -> InMemoryCollection:
        return self.get_collection(name)


_db_instance = None
_use_mock_db = False

def set_mock_db(flag: bool = True):
    global _use_mock_db, _db_instance
    _use_mock_db = flag
    if flag:
        _db_instance = InMemoryDatabase()

def get_database():
    global _db_instance
    if _use_mock_db:
        if _db_instance is None or not isinstance(_db_instance, InMemoryDatabase):
            _db_instance = InMemoryDatabase()
        return _db_instance

    if _db_instance is not None:
        return _db_instance
    
    # Check if a real remote MongoDB URI is provided
    mongo_uri = getattr(settings, "MONGO_URI", "")
    is_remote_mongo = (
        mongo_uri
        and HAS_MOTOR
        and not mongo_uri.startswith("mongodb://localhost")
        and not mongo_uri.startswith("mongodb://127.0.0.1")
    )

    if is_remote_mongo:
        try:
            client = AsyncIOMotorClient(mongo_uri, serverSelectionTimeoutMS=4000)
            _db_instance = client[settings.DATABASE_NAME]
            return _db_instance
        except Exception:
            _db_instance = InMemoryDatabase()
            return _db_instance
    else:
        _db_instance = InMemoryDatabase()
        return _db_instance
