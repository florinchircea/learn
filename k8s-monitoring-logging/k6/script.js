import http from 'k6/http';
import { check } from 'k6';
// import { sleep } from 'k6';
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";


export function handleSummary(data) {
  return {
    "/work/summary.html": htmlReport(data),
  };
}

export default function () {
  // console.log('http://'+__ENV.MY_DOMAIN+'/');
  const res = http.get('http://' + __ENV.MY_DOMAIN + '/');

  check(res, {
    'is status 200': (r) => r.status === 200,
  });

  // sleep(1); 
}
