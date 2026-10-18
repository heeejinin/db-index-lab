FROM python:3.12-slim
RUN pip install --no-cache-dir PyMySQL==1.1.1
ENV PYTHONUNBUFFERED=1 LAB_ROOT=/lab
# bench.py 는 실행할 때 레포 폴더를 /lab 으로 연결해서 읽으므로, 수정해도 다시 빌드할 필요가 없습니다.
ENTRYPOINT ["python", "/lab/bench/bench.py"]
