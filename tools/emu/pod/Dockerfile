FROM python:3.12-slim
# adb is a static x86_64 binary; the cluster nodes are x86_64.
RUN python -c "import urllib.request,zipfile,io;zipfile.ZipFile(io.BytesIO(urllib.request.urlopen('https://dl.google.com/android/repository/platform-tools-latest-linux.zip').read())).extractall('/opt')" \
 && chmod +x /opt/platform-tools/adb
ENV PATH=/opt/platform-tools:$PATH
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY adb_forwarder.py gcs.py server.py ./
RUN mkdir -p /work && ln -s /app/gcs.py /usr/local/bin/gcs && chmod +x /app/gcs.py
WORKDIR /work
EXPOSE 8080
CMD ["python", "/app/server.py"]
