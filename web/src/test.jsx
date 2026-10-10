import { useState } from 'react'
import './test.css'

function Dialogue() {
  const [count, setCount] = useState(0)

  const handleMessage = (event) => {
    var data = event.data;

    if (data !== undefined && data.type === "hide") {
      document.getElementById('root').classList.add("hidden");
    }
    if (data !== undefined && data.type === "open") {
      document.getElementById('root').classList.remove("hidden");
    }
  };

  window.addEventListener("message", handleMessage);

  return (
    <>
        <div className="container">
            <img src= "https://dunb17ur4ymx4.cloudfront.net/wysiwyg/1364588/7b504ad7f496249800123e36ecfb3905677e337d.png"></img>
            <br></br>
            <button onClick={() => setCount(count + 1)}>Click me</button>
            <p>You clicked {count} times</p>
        </div>
    </>
  )
}

export default Dialogue
