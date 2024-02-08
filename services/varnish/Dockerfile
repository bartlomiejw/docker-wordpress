# Use an Ubuntu-based image
ARG UBUNTU_VERSION
FROM ubuntu:${UBUNTU_VERSION}

# Update package lists and install Varnish
RUN apt-get update && \
    apt-get install -y varnish && \
    apt-get clean

# Copy your Varnish configuration file
COPY default.vcl /etc/varnish/default.vcl

# Expose port 80
EXPOSE 80

# Set the Varnish memory size using an ARG (you can pass it during build)
ARG VARNISH_MEMORY

# Start Varnish with the specified memory size
CMD varnishd -j unix,user=varnish -F -f /etc/varnish/default.vcl -s malloc,${VARNISH_MEMORY}
