FROM node:18.16.0
RUN mkdir ~/app
WORKDIR ~/app
COPY app/ .
RUN npm install
EXPOSE 3000
CMD ["npm", "start"]