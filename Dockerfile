# Start from the official Certbot image
FROM certbot/certbot

# Copy the modified plugin code into the container
COPY . /src/certbot-dns-namecheap

# Install the plugin and dependencies
RUN pip install --no-cache-dir --editable /src/certbot-dns-namecheap \
    && pip install --no-cache-dir dns-lexicon zope.interface requests
